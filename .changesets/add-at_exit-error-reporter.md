---
bump: major
type: add
---

Add an `at_exit` callback error reporter. By default, AppSignal will now report any unhandled errors that crash the process as long as Appsignal started beforehand.

```ruby
require "appsignal"

Appsignal.start

raise "oh no!"

# Will report the error StandardError "oh no!"
```

To disable this behavior, set the `enable_at_exit_reporter` config option to `false`.
