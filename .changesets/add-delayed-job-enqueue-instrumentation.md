---
bump: minor
type: add
---

Instrument Delayed Job enqueues. Enqueuing a job now records an
`enqueue.delayed_job` event on the active transaction, so enqueues made from
within a web request or another job show up in the event timeline.
