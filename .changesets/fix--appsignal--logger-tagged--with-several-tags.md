---
bump: patch
type: fix
---

Fix an issue when calling `Appsignal::Logger#tagged` directly with several tags. This does not affect users of `Appsignal::Logger` who also use `ActiveSupport::TaggedLogging` to wrap the logger.
