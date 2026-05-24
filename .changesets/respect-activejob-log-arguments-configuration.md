---
bump: patch
type: add
---

Respect ActiveJob's `log_arguments` configuration. When a job class has `log_arguments` set to `false`, job arguments are no longer collected for that transaction.
