---
bump: minor
type: add
---

Add `Appsignal.monitor` and `Appsignal.monitor_and_stop` instrumentation helpers. These helpers are a replacement for the `Appsignal.monitor_transaction` and `Appsignal.monitor_single_transaction` helpers.

Use these new helpers to create an AppSignal transaction and track any exceptions that occur within the instrumented block. This new helper supports custom namespaces and has a simpler way to set an action name. Use this helper in combination with our other `Appsignal.set_*` helpers to add more metadata to the transaction.

```ruby
# New helper
Appsignal.monitor(
  :namespace => "my_namespace",
  :action => "MyClass#my_method"
) do
  # Track an instrumentation event
  Appsignal.instrument("my_event.my_group") do
    # Some code
  end
end

# Old helper
Appsignal.monitor_transaction(
  "process_action.my_group",
  :class_name => "MyClass",
  :action_name => "my_method"
) do
  # Some code
end
```

The `Appsignal.monitor_and_stop` helper can be used in the same scenarios as the `Appsignal.monitor_single_transaction` helper is used. One-off Ruby scripts that are not part of a long running process.
