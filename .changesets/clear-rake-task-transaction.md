---
bump: patch
type: fix
---

Fix code that runs after a Rake task, on the same thread, not being reported. `Appsignal.monitor` did not instrument its block, and errors reported with `Appsignal.report_error` were not sent. This happened after a Rake task that raised an error, and after every Rake task when the `enable_rake_performance_instrumentation` option is enabled.
