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

# Exercise the public AppSignal metric helpers; in collector mode these
# should route through the OpenTelemetry backend and reach the mock
# collector at the configured `/v1/metrics` endpoint.
Appsignal.increment_counter("test_counter", 1, :tag => "value")
Appsignal.set_gauge("test_gauge", 42.5, :tag => "value")
Appsignal.add_distribution_value("test_distribution", 0.123, :tag => "value")

# Set by the invalid UTF-8 specs: puts the invalid string in one place, in a
# metric exported in the same batch as the valid ones above.
case ENV.fetch("INVALID_UTF8_SCENARIO", nil)
when nil
  nil
when "metric_tag_value"
  Appsignal.increment_counter("invalid_counter", 1, :invalid_tag => INVALID_STRING)
when "metric_tag_key"
  Appsignal.increment_counter("invalid_counter", 1, INVALID_STRING => "value")
else
  raise "Unknown INVALID_UTF8_SCENARIO: #{ENV.fetch("INVALID_UTF8_SCENARIO")}"
end

# Shut AppSignal down so the OTel providers drain their buffers and the
# spec sees the queued request deterministically.
Appsignal.stop("integration test")

puts "DONE"
