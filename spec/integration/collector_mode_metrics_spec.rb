if DependencyHelper.ruby_3_1_or_newer?
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/proto/collector/metrics/v1/metrics_service_pb"

  describe "AppSignal collector mode metric helpers" do
    before { OTLPCollectorServer.clear }

    it "emits OTLP metrics for set_gauge, increment_counter and add_distribution_value" do
      runner = Runner.new("collector_mode_metrics", :env => OTLPCollectorServer.env)
      runner.run

      metric_req = OTLPCollectorServer.listen_to("/v1/metrics")
      metric_msg = Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest
        .decode(metric_req[:body])

      scope_metrics = metric_msg.resource_metrics.flat_map(&:scope_metrics)
      expect(scope_metrics.map { |sm| sm.scope.name }).to include("appsignal-helpers")

      metrics_by_name = scope_metrics
        .flat_map(&:metrics)
        .to_h { |metric| [metric.name, metric] }

      expect(metrics_by_name.keys).to include("test_counter", "test_gauge", "test_distribution")

      counter = metrics_by_name.fetch("test_counter")
      expect(counter.data).to eq(:sum)
      counter_point = counter.sum.data_points.first
      expect(counter_point.as_double).to eq(1.0)
      expect(attribute_value(counter_point, "tag")).to eq("value")

      gauge = metrics_by_name.fetch("test_gauge")
      expect(gauge.data).to eq(:gauge)
      gauge_point = gauge.gauge.data_points.first
      expect(gauge_point.as_double).to eq(42.5)
      expect(attribute_value(gauge_point, "tag")).to eq("value")

      histogram = metrics_by_name.fetch("test_distribution")
      expect(histogram.data).to eq(:histogram)
      histogram_point = histogram.histogram.data_points.first
      expect(histogram_point.count).to eq(1)
      expect(histogram_point.sum).to be_within(0.0001).of(0.123)
      expect(attribute_value(histogram_point, "tag")).to eq("value")
    end

    def attribute_value(data_point, key)
      pair = data_point.attributes.find { |attr| attr.key == key }
      pair&.value&.string_value
    end
  end
end
