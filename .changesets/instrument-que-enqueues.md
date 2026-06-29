---
bump: minor
type: add
---

Instrument Que job enqueues. AppSignal now records an `enqueue.que` event when a Que job is enqueued, and a `bulk_enqueue.que` event for bulk enqueues on Que 2, so the enqueue shows up in the transaction timeline.
