---
bump: "patch"
type: "change"
---

Report all Ruby VM metrics as gauges. We previously reported some metrics as distributions, but all fields for those distributions would report the same values.
