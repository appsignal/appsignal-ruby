---
bump: patch
type: fix
---

Do not log long (error) messages to the internal AppSignal log. If an error like `ActionController::BadRequest` occurred and the error message contained the entire file upload, this would grow the `appsignal.log` file quickly if the error happens often. Internal log messages are now truncated by default.
