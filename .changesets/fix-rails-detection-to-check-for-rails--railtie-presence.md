---
bump: patch
type: fix
---

Fix Rails version detection when only one of Rails's gems is present.

This prevents loading errors when non-Rails code defines a Rails constant without the full Rails framework.