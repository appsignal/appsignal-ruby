---
bump: "patch"
type: "fix"
---

Fix an internal error when some Redis info keys we're expecting is missing. This will fix the Sidekiq dashboard showing much less data than we can report when Redis is configured to not report all the data points we expect. You'll still miss out of metrics like used memory, but miss less data than before.
