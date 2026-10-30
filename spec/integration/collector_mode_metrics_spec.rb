if DependencyHelper.opentelemetry_present?
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

    context "with invalid UTF-8" do
      # The OTLP exporter encodes each batch to protobuf in one go, and
      # protobuf refuses strings that are not valid UTF-8. One invalid string
      # then costs the whole batch, valid data included. Each example puts
      # invalid UTF-8 in one place a metric accepts input, and asserts that the
      # valid metric emitted alongside it, and the metric carrying the invalid
      # string, are both exported. The invalid bytes are expected to arrive
      # replaced with U+FFFD.
      let(:replaced) { "caf\u{FFFD}" }

      {
        "a UTF-8 string with invalid bytes" => "utf8",
        "a binary string with non-ASCII bytes" => "binary"
      }.each do |description, encoding|
        context "as #{description}" do
          let(:encoding) { encoding }

          it "exports metrics with an invalid tag value" do
            run_invalid_utf8_scenario("metric_tag_value")

            data_point = exported_invalid_counter_point
            expect(attribute_value(data_point, "invalid_tag")).to eq(replaced)
          end

          it "exports metrics with an invalid tag key" do
            run_invalid_utf8_scenario("metric_tag_key")

            data_point = exported_invalid_counter_point
            expect(attribute_value(data_point, replaced)).to eq("value")
          end
        end
      end

      def run_invalid_utf8_scenario(scenario)
        runner = Runner.new(
          "collector_mode_metrics",
          :env => OTLPCollectorServer.env.merge(
            "INVALID_UTF8_SCENARIO" => scenario,
            "INVALID_UTF8_ENCODING" => encoding
          )
        )
        runner.run
      end

      # Asserts the valid counter made it out next to the invalid one, and
      # returns the invalid counter's data point.
      #
      # The runner has stopped AppSignal and exited by the time this is
      # called, so an exported batch has already arrived. A short timeout is
      # enough: waiting longer would not make a dropped batch show up.
      def exported_invalid_counter_point
        metric_req = OTLPCollectorServer.listen_to("/v1/metrics", :timeout => 2)
        metrics_by_name = Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest
          .decode(metric_req[:body])
          .resource_metrics.flat_map(&:scope_metrics)
          .flat_map(&:metrics)
          .to_h { |metric| [metric.name, metric] }

        expect(metrics_by_name.keys).to include("test_counter", "invalid_counter")
        metrics_by_name.fetch("invalid_counter").sum.data_points.first
      end
    end

    def attribute_value(data_point, key)
      pair = data_point.attributes.find { |attr| attr.key == key }
      pair&.value&.string_value
    end
  end
end
