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

# Exercise the public AppSignal metric helpers; in collector mode these
# should route through the OpenTelemetry backend and reach the mock
# collector at the configured `/v1/metrics` endpoint.
Appsignal.increment_counter("test_counter", 1, :tag => "value")
Appsignal.set_gauge("test_gauge", 42.5, :tag => "value")
Appsignal.add_distribution_value("test_distribution", 0.123, :tag => "value")

# Force-flush so the spec can assert on the queued request deterministically.
OpenTelemetry.meter_provider.force_flush

puts "DONE"
