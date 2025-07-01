---
bump: patch
type: fix
---

When an `Appsignal::Logger` uses `.broadcast_to` to broadcast messages to other loggers, broadcast the original message received by the logger, without formatting it or converting it to a string.
