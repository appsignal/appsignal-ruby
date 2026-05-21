PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

Appsignal.configure(:test) do |config|
  config.active = true
  config.push_api_key = "abc"
  config.name = "collector-mode-test"
  config.collector_endpoint = "http://127.0.0.1:9090"
  config.service_name = "collector-mode-test-service"
  config.hostname = "test-host"
  config.revision = "abc1234"
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

# Force-flush so the spec can assert on the queued requests deterministically.
OpenTelemetry.tracer_provider.force_flush
OpenTelemetry.meter_provider.force_flush
OpenTelemetry.logger_provider.force_flush

puts "DONE"
