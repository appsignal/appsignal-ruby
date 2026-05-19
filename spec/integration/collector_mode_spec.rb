# Use the OTLP proto Ruby stubs shipped inside the
# `opentelemetry-exporter-otlp` gem to decode the bodies that the runner
# script posts to the mock collector server.
require "opentelemetry/exporter/otlp"
require "opentelemetry/proto/collector/trace/v1/trace_service_pb"
require "opentelemetry/proto/collector/metrics/v1/metrics_service_pb"
require "opentelemetry/proto/collector/logs/v1/logs_service_pb"

describe "AppSignal collector mode" do
  before { OTLPCollectorServer.clear }

  # Asserts that the OTLP Resource (proto message) carries every AppSignal
  # config attribute the runner script sets, with the right types, plus the
  # `telemetry.sdk.*` attributes from the OTel SDK's default resource. Used
  # for traces, metrics and logs alike so all three signal types are checked.
  def expect_appsignal_resource(resource) # rubocop:disable Metrics/AbcSize
    attrs = resource.attributes.to_h { |kv| [kv.key, kv.value] }

    expect(attrs["service.name"].string_value).to eq("collector-mode-test-service")
    expect(attrs["host.name"].string_value).to eq("test-host")
    expect(attrs["appsignal.config.name"].string_value).to eq("collector-mode-test")
    expect(attrs["appsignal.config.environment"].string_value).to eq("test")
    expect(attrs["appsignal.config.push_api_key"].string_value).to eq("abc")
    expect(attrs["appsignal.config.revision"].string_value).to eq("abc1234")
    expect(attrs["appsignal.config.language_integration"].string_value).to eq("ruby")
    expect(attrs["appsignal.service.process_id"].int_value).to be > 0

    expect(attrs["appsignal.config.filter_attributes"].array_value.values.map(&:string_value))
      .to eq(["password", "secret"])
    expect(attrs["appsignal.config.filter_request_payload"].array_value.values.map(&:string_value))
      .to eq(["payload-key"])
    expect(attrs["appsignal.config.ignore_actions"].array_value.values.map(&:string_value))
      .to eq(["IgnoredController#action"])
    expect(attrs["appsignal.config.ignore_namespaces"].array_value.values.map(&:string_value))
      .to eq(["background"])
    expect(attrs["appsignal.config.send_request_payload"].bool_value).to eq(false)

    # AppSignal defaults that still route into the resource.
    expect(attrs["appsignal.config.request_headers"].array_value.values.map(&:string_value))
      .to include("HTTP_ACCEPT")
    expect(attrs["appsignal.config.send_request_session_data"].bool_value).to eq(true)

    # OTel SDK metadata, kept by merging the AppSignal resource with `Resource.default`.
    expect(attrs["telemetry.sdk.name"].string_value).to eq("opentelemetry")
    expect(attrs["telemetry.sdk.language"].string_value).to eq("ruby")

    # Attributes that default to nil or [] are omitted so the collector applies defaults.
    %w[
      appsignal.config.filter_function_parameters
      appsignal.config.filter_request_query_parameters
      appsignal.config.filter_request_session_data
      appsignal.config.ignore_errors
      appsignal.config.response_headers
      appsignal.config.send_function_parameters
      appsignal.config.send_request_query_parameters
    ].each do |key|
      expect(attrs).to_not have_key(key),
        "expected #{key.inspect} to be omitted from the resource, got #{attrs[key].inspect}"
    end
  end

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
    expect_appsignal_resource(trace_msg.resource_spans.first.resource)

    metric_req = OTLPCollectorServer.listen_to("/v1/metrics")
    metric_msg = Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest
      .decode(metric_req[:body])
    metric_names = metric_msg.resource_metrics
      .flat_map { |rm| rm.scope_metrics.flat_map { |sm| sm.metrics.map(&:name) } }
    expect(metric_names).to include("test_counter")
    expect_appsignal_resource(metric_msg.resource_metrics.first.resource)

    log_req = OTLPCollectorServer.listen_to("/v1/logs")
    log_msg = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest
      .decode(log_req[:body])
    log_bodies = log_msg.resource_logs.flat_map do |rl|
      rl.scope_logs.flat_map { |sl| sl.log_records.map { |lr| lr.body.string_value } }
    end
    expect(log_bodies).to include("test-log-line")
    expect_appsignal_resource(log_msg.resource_logs.first.resource)
  end
end
