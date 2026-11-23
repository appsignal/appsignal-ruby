PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Name, environment and push API key come from the env vars the Runner
# injects (see `Runner::DEFAULT_ENV`); `Appsignal.start` loads them.
Appsignal.start

# Exercise the public AppSignal tracing helpers; in collector mode these
# should route through the OpenTelemetry transaction backend and produce
# a root span plus nested event spans reaching the mock collector at
# `/v1/traces`.
Appsignal.monitor(:action => "MyController#index") do
  Appsignal.instrument_sql("active_record.sql", "Find user", "SELECT * FROM users") do
    # No body; the SQL event span itself is what the spec asserts on.
  end
  Appsignal.instrument("template.render") do
    Appsignal.instrument("partial.render") do
      # No body; the nested event span itself is what the spec asserts on.
    end
  end
end

# Shut AppSignal down so the OTel providers drain their buffers and the
# spec sees the queued request deterministically.
Appsignal.stop("integration test")

puts "DONE"
