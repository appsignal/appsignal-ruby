---
bump: patch
type: fix
---

Avoid instrumenting Rails when AppSignal is not active. If AppSignal is configured to start when the Rails application loads, rather than after it has initialised, only add Rails' instrumentation middlewares if AppSignal was actually started.
