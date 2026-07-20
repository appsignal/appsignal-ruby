---
bump: minor
type: add
---

Improve Que support. In collector mode, AppSignal now propagates trace context when enqueuing Que jobs, so each job links back to the trace that enqueued it. This covers single and bulk enqueues, on both Que 1 and Que 2.
