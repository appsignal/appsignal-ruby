class AppsignalMock
  attr_reader :distribution_values, :gauges

  def initialize
    @distribution_values = []
    @gauges = []
  end

  def add_distribution_value(*args)
    @distribution_values << args
  end

  def set_gauge(*args)
    @gauges << args
  end
end

describe Appsignal::Probes::MriProbe do
  let(:appsignal_mock) { AppsignalMock.new }
  let(:probe) { described_class.new(appsignal_mock) }

  describe ".dependencies_present?" do
    if DependencyHelper.running_jruby? || DependencyHelper.running_ruby_2_0?
      it "should not be present" do
        expect(described_class.dependencies_present?).to be_falsy
      end
    else
      it "should be present" do
        expect(described_class.dependencies_present?).to be_truthy
      end
    end
  end

  unless DependencyHelper.running_jruby? || DependencyHelper.running_ruby_2_0?
    describe "#call" do
      before do
        probe.call
      end

      it "should track vm metrics" do
        expect_distribution_value("ruby_vm", :class_serial)
        expect_distribution_value("ruby_vm", :global_constant_state)
      end

      it "tracks thread counts" do
        expect_gauge_value("thread_count")
      end

      it "tracks GC runs" do
        expect_gauge_value("gc_runs")
      end

      it "tracks GC stats" do
        expect_gauge_value("total_allocated_objects")
        expect_distribution_value("gc_count", :major_gc_count)
        expect_distribution_value("gc_count", :minor_gc_count)
        expect_distribution_value("heap_slots", :heap_live)
        expect_distribution_value("heap_slots", :heap_free)
      end
    end
  end

  def expect_distribution_value(expected_key, metric)
    expect(appsignal_mock.distribution_values).to satisfy do |distribution_values|
      distribution_values.any? do |distribution_value|
        key, value, metadata = distribution_value
        key == expected_key && !value.nil? && metadata == {:metric => metric}
      end
    end
  end

  def expect_gauge_value(key)
    expect(appsignal_mock.gauges).to satisfy do |gauges|
      gauges.any? do |gauge|
        gauge.first == key && !gauge.last.nil?
      end
    end
  end
end
