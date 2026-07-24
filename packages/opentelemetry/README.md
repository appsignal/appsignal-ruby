# AppSignal OpenTelemetry gem

A companion gem for [`appsignal`](https://github.com/appsignal/appsignal-ruby).
It installs the OpenTelemetry gems that AppSignal needs to run in collector
mode, so you can opt into collector mode by adding a single gem to your
`Gemfile`:

```ruby
gem "appsignal"
gem "appsignal-opentelemetry"
```

Collector mode requires Ruby 3.1 or newer.

The gem itself has no runtime functionality of its own. Its only job is to depend on `appsignal` and
on the right versions of the OpenTelemetry gems. Its version is kept in lockstep
with the `appsignal` gem, so `appsignal-opentelemetry X.Y.Z` always pairs with
`appsignal X.Y.Z`.
