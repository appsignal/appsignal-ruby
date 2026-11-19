---
bump: patch
type: fix
---

Fix different Rake tasks, running on the same thread, from not being reported.
The Rake integration wasn't instrumenting the task's block which causes errors
reported with `Appsignal.report_error` to not be sent.  This happened after a
Rake task that raised an error, and after every Rake task when the
`enable_rake_performance_instrumentation` option is enabled.  
Now, the errors are reported when the task ends.
