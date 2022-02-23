---
bump: "patch"
type: "fix"
---

Fix the ActiveJob `default_queue_name` config option issue being reset to "default". When ActiveJob `default_queue_name` was set in a Rails initializer it would reset on load to `default`. Now the `default_queue_name` can be set in an initializer as well.
