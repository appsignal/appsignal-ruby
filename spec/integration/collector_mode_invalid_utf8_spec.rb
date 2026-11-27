if DependencyHelper.opentelemetry_present?
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/proto/collector/trace/v1/trace_service_pb"
  require "opentelemetry/proto/collector/metrics/v1/metrics_service_pb"
  require "opentelemetry/proto/collector/logs/v1/logs_service_pb"

  describe "AppSignal collector mode with invalid UTF-8" do
    before { OTLPCollectorServer.clear }

    it "exports traces, metrics and logs" do
      runner = Runner.new("collector_mode_invalid_utf8", :env => OTLPCollectorServer.env)
      runner.run

      trace_req = OTLPCollectorServer.listen_to("/v1/traces")
      spans = Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest
        .decode(trace_req[:body])
        .resource_spans.flat_map { |rs| rs.scope_spans.flat_map(&:spans) }
      expect(spans).to_not be_empty

      metric_req = OTLPCollectorServer.listen_to("/v1/metrics")
      metrics = Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest
        .decode(metric_req[:body])
        .resource_metrics.flat_map { |rm| rm.scope_metrics.flat_map(&:metrics) }
      expect(metrics.map(&:name)).to include(
        "invalid_utf8_counter", "invalid_utf8_gauge", "invalid_utf8_distribution"
      )

      log_req = OTLPCollectorServer.listen_to("/v1/logs")
      log_records = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest
        .decode(log_req[:body])
        .resource_logs.flat_map { |rl| rl.scope_logs.flat_map(&:log_records) }
      expect(log_records).to_not be_empty
    end
  end
end
