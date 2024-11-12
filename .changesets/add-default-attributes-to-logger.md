---
bump: patch
type: add
---

Allow for default attributes to be given when initialising a `Logger` instance:

```ruby
order_logger = Appsignal::Logger.new("app", attributes: { order_id: 123 })
```

All log lines reported by this logger will contain the given attribute. Attributes given when reporting the log line will be merged with the default attributes for the logger, with those in the log line taking priority.
