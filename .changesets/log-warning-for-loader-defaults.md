---
bump: patch
type: change
---

Log a warning when loader defaults are added after AppSignal has already been configured.

```ruby
# Bad
Appsignal.configure # or Appsignal.start
Appsignal.load(:sinatra)

# Good
Appsignal.load(:sinatra)
Appsignal.configure # or Appsignal.start
```
