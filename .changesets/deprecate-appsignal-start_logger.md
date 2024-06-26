---
bump: patch
type: deprecate
---

Deprecate the `Appsignal.start_logger` method. Remove this method call from apps if it is present. Calling `Appsignal.start` will now initialize the logger.
