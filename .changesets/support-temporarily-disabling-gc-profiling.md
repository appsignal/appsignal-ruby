---
bump: "patch"
type: "add"
---

Support temporarily disabling GC profiling without reporting inaccurate `gc_time` metric durations. The MRI probe's `gc_time` will not report any value when the `GC::Profiler.enabled?` returns `false`.
