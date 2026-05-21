PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

Appsignal.configure(:test) do |config|
  config.active = true
  config.push_api_key = "abc"
  config.name = "collector-mode-test"
  config.collector_endpoint = "http://127.0.0.1:9090"
end

Appsignal.start

# Emit one of each signal but deliberately do NOT call `force_flush`
# anywhere. The PeriodicMetricReader and BatchLogRecordProcessor buffer
# data for export at their configured interval, so anything arriving at
# the mock collector before the runner exits has to be because
# `Appsignal.stop` shut the OTel providers down (which flushes them).
Appsignal.increment_counter("stop_counter", 1)

logger = Appsignal::Logger.new("stop-group")
logger.info("stop log line")

Appsignal.stop("integration test")

puts "DONE"
