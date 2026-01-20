---
bump: patch
type: fix
---

Fix the queue time reported for the Delayed Job gem. It would report too low values, not taking into account when a job was created/enqueued.
