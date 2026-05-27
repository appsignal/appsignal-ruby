---
bump: patch
type: fix
---

Prevent a `NoMethodError` in the Active Job hook when a job is interrupted by `SIGTERM`.
