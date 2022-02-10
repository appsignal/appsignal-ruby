---
bump: "patch"
type: "change"
---

Add config override source. Track final decisions made by the Ruby gem in the configuration in the `override` config source. This will help us track new config options which are being set by their deprecated predecessors in the diagnose report.
