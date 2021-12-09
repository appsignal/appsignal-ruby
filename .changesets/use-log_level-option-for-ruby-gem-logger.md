---
bump: "patch"
type: "fix"
---

Use the `log_level` option for the Ruby gem logger. Previously it only configured the extension and agent loggers. Also fixes the `debug` and `transaction_debug_mode` option if no `log_level` is configured by the app.
