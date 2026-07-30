---
bump: minor
type: add
---

Add an `Appsignal::Transaction#add_opentelemetry_attributes` method. In collector mode, AppSignal records each transaction as an OpenTelemetry span and each instrumented event as a child span. This method adds attributes to whichever of those spans is open when you call it: the innermost event started by `Appsignal.instrument`, or the transaction's own span when no event is open.

Use it to describe what you are instrumenting in OpenTelemetry's own terms, following the OpenTelemetry semantic conventions where they apply:

```ruby
Appsignal.instrument("query.my_database") do
  Appsignal::Transaction.current.add_opentelemetry_attributes(
    "db.system.name" => "mysql"
  )
  run_the_query
end
```

Attribute values must be a String, Integer, Float or boolean. Other values are converted to a String.

Attributes have no equivalent outside collector mode, so this does nothing when collector mode is not active.
