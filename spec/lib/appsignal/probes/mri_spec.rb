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
      it "should track vm metrics" do
        probe.call

        expect_distribution_value(:class_serial)
        expect_distribution_value(:global_constant_state)
      end

      it "tracks thread counts" do
        probe.call

        expect_gauge_value(:thread_count)
      end

      it "tracks GC runs" do
        probe.call

        expect_gauge_value(:gc_runs)
      end
    end
  end

  def expect_distribution_value(metric)
    expect(appsignal_mock.distribution_values).to satisfy do |distribution_values|
      distribution_values.any? do |distribution_value|
        distribution_value.last == {:metric => metric}
      end
    end
  end

  def expect_gauge_value(key)
    expect(appsignal_mock.gauges).to satisfy do |distribution_values|
      distribution_values.any? do |distribution_value|
        distribution_value.first == key.to_s
      end
    end
  end
end
