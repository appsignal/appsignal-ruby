---
bump: patch
type: fix
---

Call the `Appsignal::Logger` formatter with the original message object given, rather than converting it to a string before calling the formatter.
