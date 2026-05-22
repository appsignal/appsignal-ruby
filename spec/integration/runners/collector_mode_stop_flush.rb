PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Name, environment and push API key come from the env vars the Runner
# injects (see `Runner::DEFAULT_ENV`); `Appsignal.start` loads them.
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
