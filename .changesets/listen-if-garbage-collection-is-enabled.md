---
bump: "patch"
type: "change"
---

Listen if the Ruby Garbage Collection profiler is enabled and collect how long the GC is running for the Ruby VM magic dashboard. An app will need to call `GC::Profiler.enable` to enable the GC profiler. Do not enable this in production environments, or at least not for long, because this can negatively impact performance of apps.
