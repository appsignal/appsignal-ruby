---
bump: patch
type: fix
---

Setting the `response_headers` configuration option to an empty list now reports no response headers in collector mode. Before this change an empty list had no effect, so every response header captured by the application's own OpenTelemetry instrumentation was reported anyway.

Leaving the option unset still reports every captured response header.
