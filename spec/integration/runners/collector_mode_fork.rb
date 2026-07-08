# A short export interval so the spec can wait a couple of seconds and
# see the periodic export tick after fork. The OTel SDK reads this env
# var when constructing the `PeriodicMetricReader`, so it has to be set
# before `Appsignal.start` boots the OTel providers.
ENV["OTEL_METRIC_EXPORT_INTERVAL"] = "500" # ms

PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Name, environment and push API key come from the env vars the Runner
# injects (see `Runner::DEFAULT_ENV`); `Appsignal.start` loads them.
Appsignal.start

# In the child: emit a metric and wait long enough for the periodic
# exporter to tick. We deliberately do NOT call any fork-aware code
# (no `Appsignal.forked`, no `force_flush`, no `Appsignal.stop`) — the
# OTel SDK's built-in fork hooks should restart the background reader
# thread on its own, triggered by `Appsignal::OpenTelemetry.configure`
# having called `OpenTelemetry::SDK.configure` at boot time.
child_pid = Process.fork do
  Appsignal.increment_counter("forked_child_counter", 1)
  sleep 2
rescue => e
  warn "child failed: #{e.class}: #{e.message}"
  warn e.backtrace
  exit!(1)
end

_, status = Process.waitpid2(child_pid)
exit(status.exitstatus || 1)
