---
bump: patch
type: add
---

Track error response status for web requests. When an unhandled exception reaches the AppSignal EventHandler instrumentation, report the response status as `500` for the `response_status` tag on the transaction and on the `response_status` metric.
