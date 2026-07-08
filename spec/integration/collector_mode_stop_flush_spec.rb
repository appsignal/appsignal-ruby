if DependencyHelper.opentelemetry_present?
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/proto/collector/metrics/v1/metrics_service_pb"
  require "opentelemetry/proto/collector/logs/v1/logs_service_pb"

  describe "AppSignal.stop in collector mode" do
    before { OTLPCollectorServer.clear }

    it "flushes buffered OTel telemetry by shutting the providers down" do
      runner = Runner.new("collector_mode_stop_flush", :env => OTLPCollectorServer.env)
      runner.run

      metric_req = OTLPCollectorServer.listen_to("/v1/metrics")
      metric_msg = Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest
        .decode(metric_req[:body])

      metric_names = metric_msg.resource_metrics
        .flat_map { |rm| rm.scope_metrics.flat_map { |sm| sm.metrics.map(&:name) } }
      expect(metric_names).to include("stop_counter")

      log_req = OTLPCollectorServer.listen_to("/v1/logs")
      log_msg = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest
        .decode(log_req[:body])

      log_bodies = log_msg.resource_logs.flat_map do |rl|
        rl.scope_logs.flat_map { |sl| sl.log_records.map { |lr| lr.body.string_value } }
      end
      expect(log_bodies).to include("stop log line")
    end
  end
end
