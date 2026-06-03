---
bump: minor
type: add
---

Add a new `collector_endpoint` configuration option (`APPSIGNAL_COLLECTOR_ENDPOINT` environment variable) that puts the integration in _collector mode_. When set, AppSignal additionally configures an OpenTelemetry SDK that exports OTLP/HTTP protobuf traces, metrics, and logs to the configured endpoint. The existing AppSignal agent continues to run unchanged; no AppSignal-collected data flows through the OpenTelemetry SDK yet.

Collector mode requires Ruby 3.1 or newer and the OpenTelemetry gems, which are optional and not installed by default. To use it, add them to your application's `Gemfile`:

```ruby
gem "opentelemetry-sdk", ">= 1.8.0"
gem "opentelemetry-metrics-sdk", ">= 0.7.1"
gem "opentelemetry-logs-sdk", ">= 0.2.0"
gem "opentelemetry-exporter-otlp", ">= 0.30.0"
gem "opentelemetry-exporter-otlp-metrics", ">= 0.4.0"
gem "opentelemetry-exporter-otlp-logs", ">= 0.2.0"
```

If these gems are missing or older than the minimum versions, AppSignal logs a warning and falls back to the bundled agent.
