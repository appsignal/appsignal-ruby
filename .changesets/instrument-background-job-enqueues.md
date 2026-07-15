---
bump: minor
type: add
---

Instrument background job enqueues. Enqueuing a job now records an enqueue
event on the active transaction, so enqueues made from within a web request or
another job show up in the event timeline. This is recorded for Sidekiq
(`enqueue.sidekiq`), Que (`enqueue.que`, plus `bulk_enqueue.que` for bulk
enqueues on Que 2), Resque (`enqueue.resque`), Shoryuken (`enqueue.shoryuken`)
and Delayed Job (`enqueue.delayed_job`). Each event is titled after the job
being enqueued.

For Active Job, the `enqueue.active_job` event is now recorded by AppSignal's
own instrumentation rather than by Rails' native `enqueue.active_job`
notification. The native notification is suppressed so the enqueue is recorded
once, and the event is now titled after the job being enqueued.

These enqueue events can be turned off with the
`enable_job_enqueue_instrumentation` config option. Set it to `false` to stop
recording enqueue events across all integrations, without affecting the
instrumentation of the jobs themselves. It defaults to `true` and can also be
set through the `APPSIGNAL_ENABLE_JOB_ENQUEUE_INSTRUMENTATION` environment
variable.
