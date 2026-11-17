---
bump: patch
type: fix
---

Fix an issue where a Sidekiq job that ran successfully could be retried by
Sidekiq.  When AppSignal's instrumentation raised an error while recording the
job's arguments, queue time or job ID after the job finished, Sidekiq treated
the job as failed and scheduled a retry, so the job ran again.  AppSignal now
logs the error in the AppSignal log, reports the job, and Sidekiq no longer
retries it.
