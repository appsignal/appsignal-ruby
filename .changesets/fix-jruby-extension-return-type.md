---
bump: patch
type: fix
---

Fix sample data not being reported for JRuby applications. Data like tags, parameters, session data, etc. would not be set if a transaction was sampled.

