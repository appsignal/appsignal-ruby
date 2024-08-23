---
bump: patch
type: fix
---

Do not log a warning for `nil` data being added as sample data, but silently ignore it because we don't support it.
