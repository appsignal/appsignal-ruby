---
bump: "patch"
type: "fix"
---

Fix an error in the diagnose report when reading a file's contents results in an "Invalid seek" error. This could happen when the log path is configured to `/dev/stdout`, which is not supported.
