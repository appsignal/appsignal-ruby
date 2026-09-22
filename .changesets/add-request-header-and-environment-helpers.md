---
bump: patch
type: add
---

Add the `Appsignal.add_request_headers` and `Appsignal.add_request_environment` helpers.

Use `add_request_headers` to report request headers, naming each header in lowercase and with dashes, such as `content-length`. Use `add_request_environment` to report the values a Rack environment holds that are not request headers, naming each one the way Rack names it, such as `REMOTE_ADDR`.

In agent mode, both write to the "Environment" sample data, formatted as Rack environment keys. In collector mode, they write different span attributes.

Together they replace `Appsignal.add_headers`, which is now deprecated, as it accepts Rack environment keys and works out which ones are headers.
