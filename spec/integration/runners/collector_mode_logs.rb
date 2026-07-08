PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Name, environment and push API key come from the env vars the Runner
# injects (see `Runner::DEFAULT_ENV`); `Appsignal.start` loads them.
Appsignal.start

# Exercise Appsignal::Logger under collector mode: in this mode each emit
# should route through Appsignal::Logger::OpenTelemetryBackend and reach
# the mock collector at the configured `/v1/logs` endpoint.
logger = Appsignal::Logger.new(
  "my-group",
  :level => ::Logger::DEBUG,
  :format => Appsignal::Logger::JSON,
  :attributes => { "service" => "runner" }
)

logger.info("info line", :tag => "value")
logger.warn("warn line")
logger.error("error line")

# Shut AppSignal down so the OTel providers drain their buffers and the
# spec sees the queued request deterministically.
Appsignal.stop("integration test")

puts "DONE"
