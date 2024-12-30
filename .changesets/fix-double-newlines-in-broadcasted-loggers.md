---
bump: patch
type: fix
---

Fix an issue where loggers, when broadcasted to by `Appsignal::Logger#broadcast_to`, would format again messages that have already been formatted by the broadcaster, causing the resulting message emitted by the logger to contain double newlines.
