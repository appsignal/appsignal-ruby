---
bump: patch
type: add
---

Add the `Appsignal.add_request_headers` and `Appsignal.add_request_environment` helpers.

Use `add_request_headers` to report request headers, naming each header the way OpenTelemetry names it, in lowercase and with dashes, such as `accept`. Use `add_request_environment` to report the values a Rack environment holds that are not request headers, naming each one the way Rack names it, such as `REMOTE_ADDR`.

Together they replace `Appsignal.add_headers`, which takes both kinds at once and has to work out which is which. `add_headers` is deprecated, and still reports the same values it did before.
