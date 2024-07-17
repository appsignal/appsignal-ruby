---
bump: patch
type: change
---

Disable the AppSignal Rack EventHandler when AppSignal is not active. It would still trigger our instrumentation when AppSignal is not active. This reduces the instrumentation overhead when AppSignal is not active.
