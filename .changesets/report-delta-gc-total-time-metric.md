---
bump: "patch"
type: "change"
---

Report Garbage Collection total time metric as the delta between measurements. This reports a more user friendly metric that doesn't always goes up until the app restarts or gets a new deploy. This metric is reported 0 by default without `GC::Profiler.enable` having been called.
