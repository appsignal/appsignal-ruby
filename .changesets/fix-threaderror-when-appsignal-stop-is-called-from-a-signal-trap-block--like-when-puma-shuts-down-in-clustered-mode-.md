---
bump: patch
type: fix
---

Fix a `ThreadError` from being raised on process exit when `Appsignal.stop` is called from a `Signal.trap` block, like when Puma shuts down in clustered mode.
