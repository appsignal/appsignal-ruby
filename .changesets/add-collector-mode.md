---
bump: minor
type: add
---

Add a new `collector_endpoint` configuration option (`APPSIGNAL_COLLECTOR_ENDPOINT` environment variable) that puts the integration in _collector mode_. When set, AppSignal additionally configures an OpenTelemetry SDK that exports OTLP/HTTP protobuf traces, metrics, and logs to the configured endpoint. The existing AppSignal agent continues to run unchanged; no AppSignal-collected data flows through the OpenTelemetry SDK yet.
