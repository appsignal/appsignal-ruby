---
bump: patch
type: fix
---

When an error is passed to an `Appsignal::Logger` as the message, format it regardless of the logging level. Previously it would only be formatted when passed to `#error`.
