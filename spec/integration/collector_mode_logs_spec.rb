require "opentelemetry/exporter/otlp"
require "opentelemetry/proto/collector/logs/v1/logs_service_pb"

describe "AppSignal collector mode log helpers" do
  before { OTLPCollectorServer.clear }

  it "emits OTLP log records through Appsignal::Logger" do
    runner = Runner.new("collector_mode_logs")
    runner.run

    log_req = OTLPCollectorServer.listen_to("/v1/logs")
    log_msg = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest
      .decode(log_req[:body])

    scope_logs = log_msg.resource_logs.flat_map(&:scope_logs)
    expect(scope_logs.map { |sl| sl.scope.name }).to include("appsignal-logger")

    records = scope_logs.flat_map(&:log_records)
    by_body = records.to_h { |record| [record.body.string_value, record] }

    expect(by_body.keys).to include("info line", "warn line", "error line")

    info_record = by_body.fetch("info line")
    expect(info_record.severity_number).to eq(:SEVERITY_NUMBER_INFO)
    expect(info_record.severity_text).to eq("INFO")
    expect(attribute_value(info_record, "appsignal.group").string_value).to eq("my-group")
    expect(attribute_value(info_record, "appsignal.format").string_value).to eq("json")
    expect(attribute_value(info_record, "service").string_value).to eq("runner")
    expect(attribute_value(info_record, "tag").string_value).to eq("value")

    warn_record = by_body.fetch("warn line")
    expect(warn_record.severity_number).to eq(:SEVERITY_NUMBER_WARN)
    expect(warn_record.severity_text).to eq("WARN")

    error_record = by_body.fetch("error line")
    expect(error_record.severity_number).to eq(:SEVERITY_NUMBER_ERROR)
    expect(error_record.severity_text).to eq("ERROR")
  end

  def attribute_value(record, key)
    record.attributes.find { |kv| kv.key == key }&.value
  end
end
