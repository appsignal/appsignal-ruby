---
bump: minor
type: add
---

Add a `collector_endpoint` configuration option (`APPSIGNAL_COLLECTOR_ENDPOINT` environment variable) that puts the integration in _collector mode_. In collector mode AppSignal reports traces, metrics and logs to an AppSignal Collector, over OTLP/HTTP.

Collector mode requires Ruby 3.1 or newer, and the OpenTelemetry gems, which are not installed by default. Add the `appsignal-opentelemetry` gem alongside `appsignal` to install them. When they are missing or too old, AppSignal logs a warning and keeps reporting through its agent.
