---
bump: minor
type: add
---

Add configuration options that map to OpenTelemetry resource attributes under collector mode: `service_name`, `filter_attributes`, `filter_function_parameters`, `filter_request_query_parameters`, `filter_request_payload`, `response_headers`, `send_function_parameters`, `send_request_query_parameters`, and `send_request_payload`. These tell the AppSignal Collector how to filter and forward telemetry data.

When collector mode is active, existing configuration options (`name`, environment, `hostname`, `revision`, `ignore_actions`, `ignore_errors`, `ignore_namespaces`, `request_headers`, `filter_session_data`, `send_session_data`) are now passed to the collector as OpenTelemetry resource attributes.

Setting any of these options without `collector_endpoint`, or `filter_parameters`/`filter_metadata`/`send_params` with `collector_endpoint`, now logs a warning at startup.
