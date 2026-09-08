---
bump: patch
type: fix
---

Report no response headers in collector mode until the `response_headers` configuration option names some. The option had no effect at all, so every response header captured by the application's own OpenTelemetry instrumentation was reported whatever the option said.
