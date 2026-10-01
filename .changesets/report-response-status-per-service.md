---
bump: patch
type: add
---

In collector mode, also report the `response_status` counter with a `service` tag. Response statuses can then be graphed per service when several services report to one app.
