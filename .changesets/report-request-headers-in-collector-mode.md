---
bump: patch
type: fix
---

Report request headers again in collector mode. The `request_headers` configuration option lists Rack environment keys, such as `HTTP_ACCEPT`, and the collector matched those against the OpenTelemetry names for the same headers, such as `accept`. Nothing matched, so every header was dropped.

Agent mode was not affected.
