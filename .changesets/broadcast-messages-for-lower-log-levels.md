---
bump: patch
type: fix
---

When an `Appsignal::Logger` uses `.broadcast_to` to broadcast messages to other loggers, broadcast those messages even if the log level of those messages is lower than the logger's threshold. This allows other loggers to set their own logging thresholds.

When the logger is silenced, messages below the silencing threshold are *not* broadcasted to other loggers.
