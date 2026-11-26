---
bump: patch
type: fix
---

Fix `Appsignal::Logger` raising a `NoMethodError` when logging an exception that has no backtrace, such as one that was never raised.
