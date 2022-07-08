---
bump: "patch"
type: "fix"
---

Fix FFI function calls missing arguments for `appsignal_free_transaction` and `appsignal_free_data` extension functions. This fixes a high CPU issue when these function calls would be retried indefinitely.
