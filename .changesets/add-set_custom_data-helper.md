---
bump: patch
type: add
---

Add `Appsignal.set_custom_data` helper to set custom data on the transaction. Previously, this could only be set with `Appsignal::Transaction.current.set_custom_data("custom_data", ...)`. This helper makes setting the custom data more convenient.
