---
bump: minor
type: add
---

Instrument Shoryuken job enqueues. Enqueuing a job now records an
`enqueue.shoryuken` event on the active transaction, so enqueues made from
within a web request or another job show up in the event timeline.
