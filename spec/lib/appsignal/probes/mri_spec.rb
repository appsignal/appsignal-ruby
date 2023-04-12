describe Appsignal::Probes::MriProbe do
  let(:appsignal_mock) { AppsignalMock.new(:hostname => hostname) }
  let(:gc_profiler_mock) { instance_double("Appsignal::GarbageCollectionProfiler") }
  let(:probe) do
    described_class.new(:appsignal => appsignal_mock, :gc_profiler => gc_profiler_mock)
  end

  describe ".dependencies_present?" do
    if DependencyHelper.running_jruby?
      it "should not be present" do
        expect(described_class.dependencies_present?).to be_falsy
      end
    else
      it "should be present" do
        expect(described_class.dependencies_present?).to be_truthy
      end
    end
  end

  unless DependencyHelper.running_jruby?
    describe "#call" do
      let(:hostname) { nil }
      before do
        allow(gc_profiler_mock).to receive(:total_time)
        allow(GC::Profiler).to receive(:enabled?).and_return(true)
      end

      it "should track vm cache metrics" do
        probe.call
        if DependencyHelper.ruby_3_2_or_newer?
          expect_gauge_value("ruby_vm", :tags => { :metric => :constant_cache_invalidations })
          expect_gauge_value("ruby_vm", :tags => { :metric => :constant_cache_misses })
        else
          expect_gauge_value("ruby_vm", :tags => { :metric => :class_serial })
          expect_gauge_value("ruby_vm", :tags => { :metric => :global_constant_state })
        end
      end

      it "tracks thread counts" do
        probe.call
        expect_gauge_value("thread_count")
      end

      it "tracks GC time between measurements" do
        expect(gc_profiler_mock).to receive(:total_time).and_return(10, 15)
        probe.call
        probe.call
        expect_gauge_value("gc_time", 5)
      end

      context "when GC total time overflows" do
        it "skips one report" do
          expect(gc_profiler_mock).to receive(:total_time).and_return(10, 15, 0, 10)
          probe.call # Normal call, create a cache
          probe.call # Report delta value based on cached value
          probe.call # The value overflows and reports no value. Then stores 0 in the cache
          probe.call # Report new value based on cache of 0
          expect_gauges([["gc_time", 5], ["gc_time", 10]])
        end
      end

      context "when GC profiling is disabled" do
        it "does not report a gc_time metric" do
          allow(GC::Profiler).to receive(:enabled?).and_return(false)
          expect(gc_profiler_mock).to_not receive(:total_time)
          probe.call # Normal call, create a cache
          probe.call # Report delta value based on cached value
          metrics = appsignal_mock.gauges.map { |(key)| key }
          expect(metrics).to_not include("gc_time")
        end

        it "does not report a gc_time metric while temporarily disabled" do
          # While enabled
          allow(GC::Profiler).to receive(:enabled?).and_return(true)
          expect(gc_profiler_mock).to receive(:total_time).and_return(10, 15)
          probe.call # Normal call, create a cache
          probe.call # Report delta value based on cached value
          expect_gauges([["gc_time", 5]])

          # While disabled
          allow(GC::Profiler).to receive(:enabled?).and_return(false)
          probe.call # Call twice to make sure any caches resets wouldn't mess up the assertion
          probe.call
          # Does not include any newly reported metrics
          expect_gauges([["gc_time", 5]])

          # When enabled after being disabled for a while, it only reports the
          # newly reported time since it was renabled
          allow(GC::Profiler).to receive(:enabled?).and_return(true)
          expect(gc_profiler_mock).to receive(:total_time).and_return(25)
          probe.call
          expect_gauges([["gc_time", 5], ["gc_time", 10]])
        end
      end

      it "tracks GC run count" do
        expect(GC).to receive(:count).and_return(10, 15)
        expect(GC).to receive(:stat).and_return(
          { :minor_gc_count => 10, :major_gc_count => 10 },
          :minor_gc_count => 16, :major_gc_count => 17
        )
        probe.call
        probe.call
        expect_gauge_value("gc_count", 5, :tags => { :metric => :gc_count })
        expect_gauge_value("gc_count", 6, :tags => { :metric => :minor_gc_count })
        expect_gauge_value("gc_count", 7, :tags => { :metric => :major_gc_count })
      end

      it "tracks object allocation" do
        expect(GC).to receive(:stat).and_return(
          { :total_allocated_objects => 10 },
          :total_allocated_objects => 15
        )
        # Only tracks delta value so the needs to be called twice
        probe.call
        probe.call
        expect_gauge_value("allocated_objects", 5)
      end

      it "tracks heap slots" do
        probe.call
        expect_gauge_value("heap_slots", :tags => { :metric => :heap_live })
        expect_gauge_value("heap_slots", :tags => { :metric => :heap_free })
      end

      context "with custom hostname" do
        let(:hostname) { "my hostname" }

        it "reports custom hostname tag value" do
          probe.call
          expect_gauge_value("heap_slots",
            :tags => { :metric => :heap_live, :hostname => hostname })
        end
      end
    end
  end

  def expect_gauge_value(expected_key, expected_value = nil, tags: {})
    expected_tags = { :hostname => Socket.gethostname }.merge(tags)
    expect(appsignal_mock.gauges).to satisfy do |gauges|
      gauges.any? do |distribution_value|
        key, value, tags = distribution_value
        next unless key == expected_key
        next unless expected_value ? expected_value == value : !value.nil?
        next unless tags == expected_tags

        true
      end
    end
  end

  def expect_gauges(expected_metrics)
    default_tags = { :hostname => Socket.gethostname }
    keys = expected_metrics.map { |(key)| key }
    metrics = expected_metrics.map do |metric|
      key, value, tags = metric
      [key, value, default_tags.merge(tags || {})]
    end
    found_gauges = appsignal_mock.gauges.select { |(key)| keys.include? key }
    expect(found_gauges).to eq(metrics)
  end
end
