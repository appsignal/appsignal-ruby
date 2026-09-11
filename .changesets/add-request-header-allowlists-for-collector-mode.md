---
bump: patch
type: add
---

Add the `keep_request_headers` and `keep_request_environment` configuration options, which are used in collector mode.

`keep_request_headers` lists the request headers to report, using the names OpenTelemetry uses for them, such as `accept` and `content-length`. `keep_request_environment` lists the Rack environment values to report that are not request headers, using the names Rack uses for them, such as `REMOTE_ADDR`.

Both options default to a value derived from `request_headers`, which lists Rack environment keys and mixes the two kinds together. So an application that only ever set `request_headers` keeps reporting the same values when it moves to collector mode. Set either option to an empty list to report none of that kind.
