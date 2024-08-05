---
bump: patch
type: deprecate
---

Deprecate the `Appsignal.listen_for_error` helper. Use a manual error rescue with `Appsignal.report_error`. This method allows for more customization of the reported error.

```ruby
# Before
Appsignal.listen_for_error do
  raise "some error"
end

begin
  raise "some error"
rescue => error
  Appsignal.report_error(error)
end
```

Read our [Exception handling guide](https://docs.appsignal.com/ruby/instrumentation/exception-handling.html) for more information.
