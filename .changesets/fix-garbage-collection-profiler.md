---
bump: "patch"
type: "fix"
---

Fix the MRI probe using the Garbage Collection profiler instead of the NilProfiler when garbage collection instrumentation is not enabled for MRI probe. This caused unnecessary overhead.
