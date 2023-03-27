---
bump: "patch"
type: "add"
---

Support "warning" value for `log_level` config option. This option was documented, but wasn't accepted and fell back on the "info" log level if used. Now it works to configure it to the "warn"/"warning" log level.
