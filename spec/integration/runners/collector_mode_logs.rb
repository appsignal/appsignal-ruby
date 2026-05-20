PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "fileutils"
require "appsignal"

Appsignal.configure(:test) do |config|
  config.active = true
  config.push_api_key = "abc"
  config.name = "collector-mode-test"
  config.collector_endpoint = "http://127.0.0.1:9090"

  working_directory = "tmp/appsignal"
  FileUtils.rm_rf(working_directory)
  FileUtils.mkdir_p(working_directory)
  config.working_directory_path = File.join(__dir__, working_directory)
end

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

# Force-flush so the spec can assert on the queued request deterministically.
OpenTelemetry.logger_provider.force_flush

puts "DONE"
