---
bump: patch
type: fix
---

Fix the queue time reporting for Sidekiq 8 jobs. It would report high negative values for the queue time with Sidekiq 8.
