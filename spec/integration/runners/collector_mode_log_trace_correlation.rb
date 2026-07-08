PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Name, environment and push API key come from the env vars the Runner
# injects (see `Runner::DEFAULT_ENV`); `Appsignal.start` loads them.
Appsignal.start

logger = Appsignal::Logger.new("correlation-group")

# Emit one log under the root span (no active event), one nested inside
# an `Appsignal.instrument` event, and one after the event closes. Each
# should carry the trace_id/span_id of whichever span was current at
# emit time.
Appsignal.monitor(:action => "TestAction") do
  logger.info("before event")
  Appsignal.instrument("test.event") do
    logger.info("inside event")
  end
  logger.info("after event")
end

Appsignal.stop("integration test")

puts "DONE"
