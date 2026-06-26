---
bump: patch
type: change
---

Record the `enqueue.active_job` event from AppSignal's own Active Job
instrumentation rather than from Rails' native `enqueue.active_job`
notification, which is now suppressed so the enqueue is recorded once. The
event still shows up on the active transaction when enqueuing from within a web
request or another job; there is no change to what you see.
