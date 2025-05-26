---
bump: patch
type: fix
---

Resolve problems with transactions not being properly closed when using libraries that change Fibers during the transactions. Previously, completed transactions would be attempted to be reused when creating a transaction, when the Fiber would be switched during a transaction.
