PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

INVALID_STRING = "caf\xE9".dup.force_encoding(Encoding::UTF_8)

# The OTLP exporter encodes each batch to protobuf, which rejects strings that
# are not valid UTF-8 and discards the whole batch with them.
Appsignal.configure do |config|
  config.service_name = INVALID_STRING
  config.hostname = INVALID_STRING
  config.revision = INVALID_STRING
  config.filter_attributes = [INVALID_STRING]
  config.filter_request_payload = [INVALID_STRING]
  config.filter_session_data = [INVALID_STRING]
  config.keep_request_headers = ["accept", INVALID_STRING]
  config.request_headers = ["REMOTE_ADDR", INVALID_STRING]
  # Not the action and namespace used below, or the transaction is ignored.
  config.ignore_actions = ["Ignored#{INVALID_STRING}"]
  config.ignore_namespaces = ["ignored_#{INVALID_STRING}"]
end

Appsignal.start

def error_with_invalid_cause
  begin
    raise ArgumentError, INVALID_STRING
  rescue ArgumentError => cause
    cause.set_backtrace(["/app/#{INVALID_STRING}.rb:1:in `cause'"])
    raise StandardError, INVALID_STRING
  end
rescue StandardError => error
  error.set_backtrace(["/app/#{INVALID_STRING}.rb:2:in `error'"])
  error
end

Appsignal.monitor(:namespace => INVALID_STRING, :action => INVALID_STRING) do
  Appsignal.add_tags(INVALID_STRING => INVALID_STRING)
  Appsignal::Transaction.current.set_metadata(INVALID_STRING, INVALID_STRING)
  Appsignal.add_params(INVALID_STRING => INVALID_STRING)
  Appsignal.add_session_data(INVALID_STRING => INVALID_STRING)
  Appsignal.add_custom_data(INVALID_STRING => [INVALID_STRING])
  Appsignal.add_request_headers("accept" => INVALID_STRING, INVALID_STRING => INVALID_STRING)
  Appsignal.add_request_environment("REMOTE_ADDR" => INVALID_STRING)
  Appsignal::Transaction.current
    .add_opentelemetry_attributes(INVALID_STRING => INVALID_STRING)
  Appsignal.add_breadcrumb(INVALID_STRING, INVALID_STRING, INVALID_STRING,
    INVALID_STRING => INVALID_STRING)
  Appsignal.instrument(INVALID_STRING, INVALID_STRING, INVALID_STRING) do
    # No body; the event carries the invalid strings.
  end
  Appsignal.instrument_sql(INVALID_STRING, INVALID_STRING, INVALID_STRING) do
    # No body; the event carries the invalid strings.
  end
  Appsignal.set_error(error_with_invalid_cause)
end

# A metric name OpenTelemetry rejects is dropped, so the other metrics use a
# valid name and carry the invalid strings in their tags.
Appsignal.increment_counter(INVALID_STRING, 1, INVALID_STRING => INVALID_STRING)
Appsignal.increment_counter("invalid_utf8_counter", 1, INVALID_STRING => INVALID_STRING)
Appsignal.set_gauge("invalid_utf8_gauge", 1, INVALID_STRING => INVALID_STRING)
Appsignal.add_distribution_value("invalid_utf8_distribution", 1,
  INVALID_STRING => INVALID_STRING)

logger = Appsignal::Logger.new(INVALID_STRING, :attributes => { INVALID_STRING => INVALID_STRING })
logger.info(INVALID_STRING, INVALID_STRING => INVALID_STRING)

# Shut AppSignal down so the OTel providers drain their buffers and the
# spec sees the queued requests deterministically.
Appsignal.stop("integration test")

puts "DONE"
