---
bump: patch
type: add
---

Improve instrumentation of Hanami requests by making sure the transaction is always closed.
It will also report a `response_status` tag and metric for Hanami requests.
