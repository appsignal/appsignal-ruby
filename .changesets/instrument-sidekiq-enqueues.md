---
bump: minor
type: add
---

Instrument Sidekiq job enqueues. Enqueuing a job now records an
`enqueue.sidekiq` event on the active transaction, so enqueues made from within
a web request or another job show up in the event timeline.
