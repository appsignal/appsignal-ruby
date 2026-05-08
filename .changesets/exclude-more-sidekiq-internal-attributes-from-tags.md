---
bump: patch
type: change
---

Exclude more Sidekiq internal job attributes (`cattr`, `tags`, `retry_for` and `unique_for`) from the tags reported for Sidekiq jobs.
