---
bump: minor
type: add
---

Add Sidekiq worker-level success and failure metrics.

### Added
- New Sidekiq worker metrics to track job success and failure rates per worker class
    - `worker_job_count` - Counter incremented when a job runs.
    - The metric is tagged with `:worker`, `queue` and `status`.
