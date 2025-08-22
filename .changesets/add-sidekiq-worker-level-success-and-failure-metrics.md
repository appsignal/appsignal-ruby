---
bump: minor
type: add
---

Add Sidekiq worker-level job status metric: `worker_job_count`. This new counter metric's `status` tag will be `processed` for each job that's processed and reports another counter with the `failure` status if the job encountered an error.
