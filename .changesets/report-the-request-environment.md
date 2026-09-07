---
bump: patch
type: add
---

Report the request environment in collector mode. The `request_headers` configuration option is an allowlist of Rack environment names, and some of those names are not request headers. Those values are now reported as `appsignal.environment.*` OpenTelemetry attributes and shown in the request's Environment panel, instead of being left out.

Values that describe the request itself are not repeated there, because they are already reported as the request's method, path, host, port and protocol version.
