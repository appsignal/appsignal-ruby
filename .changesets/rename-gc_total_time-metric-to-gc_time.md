---
bump: "patch"
type: "change"
---

Rename the (so far privately reported) `gc_total_time` metric to `gc_time`. It no longer reports the total time of Garbage Collection measured, but only the time between two (minutely) measurements.
