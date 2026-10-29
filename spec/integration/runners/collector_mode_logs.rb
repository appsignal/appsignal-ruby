PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Set by the invalid UTF-8 specs: a String tagged UTF-8 holding a byte that
# is not UTF-8, or a binary String with a byte above 127.
INVALID_STRING =
  case ENV.fetch("INVALID_UTF8_ENCODING", nil)
  when "utf8" then "caf\xE9".dup.force_encoding(Encoding::UTF_8)
  when "binary" then "caf\xE9".b
  end

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

# Set by the invalid UTF-8 specs: puts the invalid string in one place, in a
# log line exported in the same batch as the valid ones above.
case ENV.fetch("INVALID_UTF8_SCENARIO", nil)
when nil
  nil
when "log_message"
  Appsignal::Logger.new("invalid-group").info(INVALID_STRING)
when "log_attribute_value"
  Appsignal::Logger.new("invalid-group").info("invalid line", :invalid_attribute => INVALID_STRING)
when "log_attribute_key"
  Appsignal::Logger.new("invalid-group").info("invalid line", INVALID_STRING => "value")
when "log_group"
  Appsignal::Logger.new(INVALID_STRING).info("invalid line")
else
  raise "Unknown INVALID_UTF8_SCENARIO: #{ENV.fetch("INVALID_UTF8_SCENARIO")}"
end

# Shut AppSignal down so the OTel providers drain their buffers and the
# spec sees the queued request deterministically.
Appsignal.stop("integration test")

puts "DONE"
