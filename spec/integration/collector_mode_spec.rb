# Use the OTLP proto Ruby stubs shipped inside the
# `opentelemetry-exporter-otlp` gem to decode the bodies that the runner
# script posts to the mock collector server.
require "opentelemetry/exporter/otlp"
require "opentelemetry/proto/collector/trace/v1/trace_service_pb"
require "opentelemetry/proto/collector/metrics/v1/metrics_service_pb"
require "opentelemetry/proto/collector/logs/v1/logs_service_pb"

describe "AppSignal collector mode" do
  before { OTLPCollectorServer.clear }

  it "configures collector mode and emits OTLP traces, metrics, and logs" do
    runner = Runner.new("collector_mode_emit")
    runner.run

    expect(runner.status.exitstatus).to eq(0), "runner failed:\n#{runner.output}"
    expect(runner.output).to include("DONE")

    # Config wiring: the child process saw the value and computed the predicate.
    expect(runner.output).to include("collector_endpoint=http://127.0.0.1:9090")
    expect(runner.output).to include("collector_mode?=true")

    trace_req = OTLPCollectorServer.listen_to("/v1/traces")
    trace_msg = Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest
      .decode(trace_req[:body])
    span_names = trace_msg.resource_spans
      .flat_map { |rs| rs.scope_spans.flat_map { |ss| ss.spans.map(&:name) } }
    expect(span_names).to include("test-span")

    metric_req = OTLPCollectorServer.listen_to("/v1/metrics")
    metric_msg = Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest
      .decode(metric_req[:body])
    metric_names = metric_msg.resource_metrics
      .flat_map { |rm| rm.scope_metrics.flat_map { |sm| sm.metrics.map(&:name) } }
    expect(metric_names).to include("test_counter")

    log_req = OTLPCollectorServer.listen_to("/v1/logs")
    log_msg = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest
      .decode(log_req[:body])
    log_bodies = log_msg.resource_logs.flat_map do |rl|
      rl.scope_logs.flat_map { |sl| sl.log_records.map { |lr| lr.body.string_value } }
    end
    expect(log_bodies).to include("test-log-line")
  end
end
