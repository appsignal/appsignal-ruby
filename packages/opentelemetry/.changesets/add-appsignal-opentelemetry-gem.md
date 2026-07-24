---
bump: minor
type: add
---

Add the `appsignal-opentelemetry` gem. It installs the OpenTelemetry gems that AppSignal needs to run in collector mode. Add it alongside `appsignal` to opt into collector mode with a single gem instead of listing each OpenTelemetry gem yourself:

```ruby
gem "appsignal"
gem "appsignal-opentelemetry"
```

Collector mode requires Ruby 3.1 or newer, so this gem does too. Its version stays in lockstep with the `appsignal` gem.
