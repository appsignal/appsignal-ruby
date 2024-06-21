---
bump: minor
type: add
---

Report Sidekiq errors when a job is dead/discarded. Configure the new `sidekiq_report_errors` config option to "discard" to only report errors when the job is not retried further.
