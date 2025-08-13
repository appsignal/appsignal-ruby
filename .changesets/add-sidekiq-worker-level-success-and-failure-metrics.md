---
bump: minor
type: add
---

Add Sidekiq worker-level job status metric: `worker_job_count`. This new counter metric's `status` tag will either be `success` or `failure` depending on if it the job encountered an error or not.
