---
bump: "patch"
type: "change"
---

Log a warning when no mountpoints are found to report the disk usage metrics. This scenario shouldn't happen (it should log an error, message about skipping a mountpoint or log the disk usage). Log a warning to detect if this issue really occurs.
