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

      # The two metric tags depend on the Ruby version.
      def vm_cache_metrics
        if DependencyHelper.ruby_3_2_or_newer?
          [:constant_cache_invalidations, :constant_cache_misses]
        else
          [:class_serial, :global_constant_state]
        end
      end

      describe "the vm cache gauges" do
        def perform(probe)
          probe.call
        end

        it "in agent mode", :agent_mode do
          perform(probe)
          vm_cache_metrics.each do |metric|
            expect_gauge_value("ruby_vm", :tags => { :metric => metric })
          end
        end

        it "in collector mode", :collector_mode do
          perform(collector_probe)

          snapshots = metric_snapshots
          vm_cache_metrics.each do |metric|
            point = find_gauge_point(snapshots, "ruby_vm", :metric => metric)
            expect(point.value).to be_a(Numeric)
          end
        end
      end

      describe "the thread count gauge" do
        def perform(probe)
          probe.call
        end

        it "in agent mode", :agent_mode do
          perform(probe)
          expect_gauge_value("thread_count")
        end

        it "in collector mode", :collector_mode do
          perform(collector_probe)

          snapshot = metric_snapshot("thread_count")
          expect(snapshot).not_to be_nil
          expect(snapshot.instrument_kind).to eq(:gauge)
          data_point = snapshot.data_points.first
          expect(data_point.value).to be_a(Numeric)
          expect(data_point.attributes).to include("hostname" => kind_of(String))
        end
      end

      describe "the gc time gauge" do
        # The gauge reports the delta between measurements, so call twice.
        def perform(probe)
          expect(gc_profiler_mock).to receive(:total_time).and_return(10, 15)
          probe.call
          probe.call
        end

        it "in agent mode", :agent_mode do
          perform(probe)
          expect_gauge_value("gc_time", 5)
        end

        it "in collector mode", :collector_mode do
          perform(collector_probe)
          expect(find_gauge_point(metric_snapshots, "gc_time").value).to eq(5)
        end
      end

      context "when GC total time overflows" do
        describe "skips one report" do
          def perform(probe)
            expect(gc_profiler_mock).to receive(:total_time).and_return(10, 15, 0, 10)
            probe.call # Normal call, create a cache
            probe.call # Report delta value based on cached value
            probe.call # The value overflows and reports no value. Then stores 0 in the cache
            probe.call # Report new value based on cache of 0
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform(probe)
            expect_gauges([["gc_time", 5], ["gc_time", 10]])
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform(collector_probe)
            # An OTel gauge keeps only its last value, so assert the final
            # post-overflow value (10) rather than the agent's [5, 10] sequence.
            # This still confirms the metric is emitted through the overflow.
            expect(find_gauge_point(metric_snapshots, "gc_time").value).to eq(10)
          end
        end
      end

      context "when GC profiling is disabled" do
        describe "the gc time gauge" do
          def perform(probe)
            allow(GC::Profiler).to receive(:enabled?).and_return(false)
            expect(gc_profiler_mock).to_not receive(:total_time)
            probe.call # Normal call, create a cache
            probe.call # Report delta value based on cached value
          end

          it "does not report a gc_time metric in agent mode", :agent_mode do
            perform(probe)
            metrics = appsignal_mock.gauges.map { |(key)| key }
            expect(metrics).to_not include("gc_time")
          end

          it "does not report a gc_time metric in collector mode", :collector_mode do
            perform(collector_probe)
            expect(metric_snapshots.map(&:name)).to_not include("gc_time")
          end
        end

        describe "does not report a gc_time metric while temporarily disabled" do
          def perform(probe)
            # While enabled
            allow(GC::Profiler).to receive(:enabled?).and_return(true)
            expect(gc_profiler_mock).to receive(:total_time).and_return(10, 15)
            probe.call # Normal call, create a cache
            probe.call # Report delta value based on cached value

            # While disabled
            allow(GC::Profiler).to receive(:enabled?).and_return(false)
            probe.call # Call twice to make sure any cache resets wouldn't mess up the assertion
            probe.call

            # When enabled after being disabled for a while, it only reports the
            # newly reported time since it was renabled
            allow(GC::Profiler).to receive(:enabled?).and_return(true)
            expect(gc_profiler_mock).to receive(:total_time).and_return(25)
            probe.call
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform(probe)
            # Exactly two emissions: the disabled phase reported nothing.
            expect_gauges([["gc_time", 5], ["gc_time", 10]])
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform(collector_probe)
            # The gauge keeps its last value; assert the post-re-enable value
            # (10), confirming the disable/re-enable cache logic emits correctly.
            expect(find_gauge_point(metric_snapshots, "gc_time").value).to eq(10)
          end
        end
      end

      describe "the gc run count gauge" do
        # The gauges report deltas between measurements, so call twice.
        def perform(probe)
          expect(GC).to receive(:count).and_return(10, 15)
          expect(GC).to receive(:stat).and_return(
            { :minor_gc_count => 10, :major_gc_count => 10 },
            :minor_gc_count => 16, :major_gc_count => 17
          )
          probe.call
          probe.call
        end

        it "in agent mode", :agent_mode do
          perform(probe)
          expect_gauge_value("gc_count", 5, :tags => { :metric => :gc_count })
          expect_gauge_value("gc_count", 6, :tags => { :metric => :minor_gc_count })
          expect_gauge_value("gc_count", 7, :tags => { :metric => :major_gc_count })
        end

        it "in collector mode", :collector_mode do
          perform(collector_probe)
          snapshots = metric_snapshots
          expect(find_gauge_point(snapshots, "gc_count", :metric => :gc_count).value).to eq(5)
          expect(find_gauge_point(snapshots, "gc_count", :metric => :minor_gc_count).value).to eq(6)
          expect(find_gauge_point(snapshots, "gc_count", :metric => :major_gc_count).value).to eq(7)
        end
      end

      describe "the allocated objects gauge" do
        # Only tracks the delta value, so it needs to be called twice.
        def perform(probe)
          expect(GC).to receive(:stat).and_return(
            { :total_allocated_objects => 10 },
            :total_allocated_objects => 15
          )
          probe.call
          probe.call
        end

        it "in agent mode", :agent_mode do
          perform(probe)
          expect_gauge_value("allocated_objects", 5)
        end

        it "in collector mode", :collector_mode do
          perform(collector_probe)
          expect(find_gauge_point(metric_snapshots, "allocated_objects").value).to eq(5)
        end
      end

      describe "the heap slots gauges" do
        def perform(probe)
          probe.call
        end

        it "in agent mode", :agent_mode do
          perform(probe)
          expect_gauge_value("heap_slots", :tags => { :metric => :heap_live })
          expect_gauge_value("heap_slots", :tags => { :metric => :heap_free })
        end

        it "in collector mode", :collector_mode do
          perform(collector_probe)
          snapshots = metric_snapshots
          expect(find_gauge_point(snapshots, "heap_slots", :metric => :heap_live).value)
            .to be_a(Numeric)
          expect(find_gauge_point(snapshots, "heap_slots", :metric => :heap_free).value)
            .to be_a(Numeric)
        end
      end

      context "with custom hostname" do
        let(:hostname) { "my hostname" }
        # Collector mode reads the hostname from the real Appsignal config; agent
        # mode reads it from the AppsignalMock, which carries it directly.
        let(:start_agent_args) { { :options => { :hostname => hostname } } }

        describe "reports custom hostname tag value" do
          def perform(probe)
            probe.call
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform(probe)
            expect_gauge_value("heap_slots",
              :tags => { :metric => :heap_live, :hostname => hostname })
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform(collector_probe)
            point = find_gauge_point(metric_snapshots, "heap_slots",
              :metric => :heap_live, :hostname => hostname)
            expect(point.attributes["hostname"]).to eq(hostname)
          end
        end
      end
    end
  end

  # A probe wired to the real Appsignal so `set_gauge` routes through the OTel
  # metrics backend (collector mode) instead of the in-memory AppsignalMock.
  def collector_probe
    described_class.new(:appsignal => Appsignal, :gc_profiler => gc_profiler_mock)
  end

  # Find a single gauge data point in the pulled snapshots by metric name and
  # (stringified) tags, asserting the snapshot exists, is a gauge, and carries a
  # hostname. Tag values are compared as strings since OTel stringifies them.
  def find_gauge_point(snapshots, name, tags = {})
    snapshot = snapshots.find { |s| s.name == name }
    expect(snapshot).not_to(be_nil, "expected a #{name} snapshot")
    expect(snapshot.instrument_kind).to eq(:gauge)
    point = snapshot.data_points.find do |p|
      tags.all? { |key, value| p.attributes[key.to_s] == value.to_s }
    end
    expect(point).not_to(be_nil, "expected #{name} point with tags #{tags}")
    expect(point.attributes).to include("hostname" => kind_of(String))
    point
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
