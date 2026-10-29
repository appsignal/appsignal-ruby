PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Set by the invalid UTF-8 specs: a String tagged UTF-8 holding a byte that
# is not UTF-8, or a binary String with a byte above 127. Used as the
# revision, which ends up in the resource of every exported batch.
INVALID_STRING =
  case ENV.fetch("INVALID_UTF8_ENCODING", nil)
  when "utf8" then "caf\xE9".dup.force_encoding(Encoding::UTF_8)
  when "binary" then "caf\xE9".b
  end

# Name, environment and push API key come from the env vars the Runner
# injects (see `Runner::DEFAULT_ENV`). The options below are specific to
# this test's resource-attribute assertions.
Appsignal.configure do |config|
  config.service_name = "collector-mode-test-service"
  config.hostname = "test-host"
  config.revision = INVALID_STRING || "abc1234"
  config.filter_attributes = ["password", "secret"]
  config.filter_request_payload = ["payload-key"]
  config.send_request_payload = false
  config.ignore_actions = ["IgnoredController#action"]
  config.ignore_namespaces = ["background"]
end

Appsignal.start

# Print config state so the spec can verify the option round-trips end-to-end.
puts "collector_endpoint=#{Appsignal.config[:collector_endpoint]}"
puts "collector_mode?=#{Appsignal.config.collector_mode?}"

# Emit one of each OTLP signal through the OpenTelemetry SDK that
# `Appsignal::OpenTelemetry.configure` has just set up.
tracer = OpenTelemetry.tracer_provider.tracer("collector-mode-runner")
tracer.in_span("test-span") { |span| span.set_attribute("test.key", "test.value") }

meter = OpenTelemetry.meter_provider.meter("collector-mode-runner")
meter.create_counter("test_counter").add(1)

logger = OpenTelemetry.logger_provider.logger(:name => "collector-mode-runner")
logger.on_emit(:severity_text => "INFO", :body => "test-log-line")

# Shut AppSignal down so the OTel providers drain their buffers and the
# spec sees the queued requests deterministically.
Appsignal.stop("integration test")

puts "DONE"
