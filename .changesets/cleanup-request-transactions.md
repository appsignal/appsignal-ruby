---
bump: patch
type: fix
---

Fix an issue where transactions would be reused across requests when an error happened before the transaction could be closed, which would lead to errors being returned by the app itself.
