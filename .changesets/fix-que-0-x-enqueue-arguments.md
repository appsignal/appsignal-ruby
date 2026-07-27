---
bump: patch
type: fix
---

Fix Que jobs being corrupted on enqueue when using Que 0.x. This was introduced
in version 4.9.0. Que 1 and Que 2 were not affected.
