---
bump: "patch"
type: "fix"
---

Clear the AppSignal in memory logger, used during the gem start, after the file/STDOUT logger is started. This reduces memory usage of the AppSignal Ruby gem by a tiny bit, and prevent stale logs being logged whenever a process gets forked and starts AppSignal.
