# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry-metrics-sdk"

describe Appsignal::Metrics::OpenTelemetryBackend do
  let(:exporter) { ::OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new }
  let(:meter_provider) do
    provider = ::OpenTelemetry::SDK::Metrics::MeterProvider.new
    provider.add_metric_reader(exporter)
    provider
  end

  before do
    ::OpenTelemetry.meter_provider = meter_provider
    described_class.reset!
  end

  after { described_class.reset! }

  def collect_snapshots
    exporter.pull
    snapshots = exporter.metric_snapshots.dup
    exporter.reset
    snapshots
  end

  def snapshot_for(name)
    collect_snapshots.find { |snapshot| snapshot.name == name }
  end

  describe ".set_gauge" do
    it "emits a Gauge snapshot with the recorded value and attributes" do
      described_class.set_gauge("my_gauge", 42.5, { :host => "node-1" })

      snapshot = snapshot_for("my_gauge")
      expect(snapshot).not_to be_nil
      expect(snapshot.instrument_kind).to eq(:gauge)
      expect(snapshot.data_points.first.value).to eq(42.5)
      expect(snapshot.data_points.first.attributes).to eq("host" => "node-1")
    end

    it "coerces integer values to float" do
      described_class.set_gauge("my_gauge", 10, {})

      snapshot = snapshot_for("my_gauge")
      expect(snapshot.data_points.first.value).to eq(10.0)
    end
  end

  describe ".increment_counter" do
    it "emits an UpDownCounter snapshot whose sum tracks repeated calls" do
      described_class.increment_counter("my_counter", 1, { :endpoint => "/" })
      described_class.increment_counter("my_counter", 3, { :endpoint => "/" })

      snapshot = snapshot_for("my_counter")
      expect(snapshot).not_to be_nil
      expect(snapshot.instrument_kind).to eq(:up_down_counter)
      expect(snapshot.data_points.first.value).to eq(4.0)
      expect(snapshot.data_points.first.attributes).to eq("endpoint" => "/")
    end

    it "accepts negative increments" do
      described_class.increment_counter("my_counter", -5, {})

      snapshot = snapshot_for("my_counter")
      expect(snapshot.data_points.first.value).to eq(-5.0)
    end
  end

  describe ".add_distribution_value" do
    it "emits a Histogram snapshot capturing the recorded values" do
      described_class.add_distribution_value("my_distribution", 0.1, { :route => "/login" })
      described_class.add_distribution_value("my_distribution", 0.2, { :route => "/login" })

      snapshot = snapshot_for("my_distribution")
      expect(snapshot).not_to be_nil
      expect(snapshot.instrument_kind).to eq(:histogram)
      data_point = snapshot.data_points.first
      expect(data_point.count).to eq(2)
      expect(data_point.sum).to be_within(0.0001).of(0.3)
      expect(data_point.attributes).to eq("route" => "/login")
    end
  end

  describe "attribute coercion" do
    it "stringifies symbol keys and symbol values, preserves primitives" do
      described_class.set_gauge(
        "my_gauge",
        1.0,
        {
          :string => "value",
          "symbol" => :sym,
          :integer => 42,
          :float => 1.5,
          :truthy => true,
          :falsy => false
        }
      )

      attrs = snapshot_for("my_gauge").data_points.first.attributes
      expect(attrs).to eq(
        "string" => "value",
        "symbol" => "sym",
        "integer" => 42,
        "float" => 1.5,
        "truthy" => true,
        "falsy" => false
      )
    end

    it "coerces other tag value types via to_s" do
      described_class.set_gauge("my_gauge", 1.0, { :time => Time.utc(2026, 1, 2, 3, 4, 5) })

      attrs = snapshot_for("my_gauge").data_points.first.attributes
      expect(attrs["time"]).to eq("2026-01-02 03:04:05 UTC")
    end

    it "treats an empty tags hash as no attributes" do
      described_class.increment_counter("my_counter", 1, {})

      attrs = snapshot_for("my_counter").data_points.first.attributes
      expect(attrs).to eq({})
    end
  end

  describe "instrument caching" do
    it "reuses the same instrument across calls for a given metric name" do
      meter = ::OpenTelemetry.meter_provider.meter("appsignal-helpers")
      expect(meter).to receive(:create_up_down_counter).once.and_call_original

      described_class.increment_counter("cached_counter", 1, {})
      described_class.increment_counter("cached_counter", 1, {})
    end

    it "uses the 'appsignal-helpers' meter scope name" do
      described_class.set_gauge("scoped_gauge", 1.0, {})

      snapshot = snapshot_for("scoped_gauge")
      expect(snapshot.instrumentation_scope.name).to eq("appsignal-helpers")
    end
  end
end
