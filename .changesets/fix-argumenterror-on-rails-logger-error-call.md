---
bump: patch
type: fix
---

Fix ArgumentError being raised on Ruby logger and Rails.logger error calls. This fixes the error from being raised from within the AppSignal Ruby gem.
Please do not use this for error reporting. We recommend using our error reporting feature instead to be notified of new errors. Read more on [exception handling in Ruby with our Ruby gem](https://docs.appsignal.com/ruby/instrumentation/exception-handling.html).

```ruby
# No longer raises an error
Rails.logger.error StandardError.new("StandardError log message")
```
