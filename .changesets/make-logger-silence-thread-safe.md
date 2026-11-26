---
bump: patch
type: fix
---

Make `Appsignal::Logger#silence` thread-safe. The silence level is now stored per thread, so two overlapping `silence` calls, such as concurrent Rails health check requests, no longer leave the logger stuck at the `ERROR` level.
