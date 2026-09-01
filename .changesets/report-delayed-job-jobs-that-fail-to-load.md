---
bump: patch
type: fix
---

Report Delayed Job jobs that fail to load. Before this change, a job whose
payload could not be deserialized was not reported to AppSignal at all.

This can happen when a deploy removes or renames a job class while jobs of that
class are still queued. Those jobs are now reported as failed, with the
`Delayed::DeserializationError` they raised, and are named after the class
recorded in the job's handler. When even that cannot be read, they are named
`Delayed::Job#perform`.
