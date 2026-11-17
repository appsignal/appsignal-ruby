---
bump: patch
type: fix
---

Fix an issue where AppSignal did not report data for code that ran after a Rake
task in the same process.  After the task, `Appsignal.monitor` did not
instrument its block, and errors reported with `Appsignal.report_error` were not
sent to AppSignal.  This happened after Rake tasks that raised an error, and
after any Rake task when the `enable_rake_performance_instrumentation` option
was enabled.
