---
bump: minor
type: add
---

Add an `Appsignal::Transaction#add_opentelemetry_attributes` method. It adds OpenTelemetry attributes to the span AppSignal is currently recording: the innermost event opened by `Appsignal.instrument`, or the transaction itself when no event is open.

Use it to describe what you are instrumenting in OpenTelemetry's own terms, following the OpenTelemetry semantic conventions where they apply:

```ruby
Appsignal.instrument("query.my_database") do
  Appsignal::Transaction.current.add_opentelemetry_attributes(
    "db.system.name" => "mysql"
  )
  run_the_query
end
```

Values must be a String, Integer, Float or boolean. Anything else is converted to a String. This does nothing outside collector mode.
