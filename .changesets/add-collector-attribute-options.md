---
bump: minor
type: add
---

Add configuration options that map to OpenTelemetry resource attributes in collector mode: `service_name`, `filter_attributes`, `filter_function_parameters`, `filter_request_query_parameters`, `filter_request_payload`, `response_headers`, `send_function_parameters`, `send_request_query_parameters` and `send_request_payload`.

In collector mode, existing options are passed to the collector as resource attributes as well: `name`, environment, `hostname`, `revision`, `ignore_actions`, `ignore_errors`, `ignore_namespaces`, `request_headers`, `filter_session_data` and `send_session_data`.

Setting any of these without `collector_endpoint`, or setting `filter_parameters`, `filter_metadata` or `send_params` with it, logs a warning at startup.
