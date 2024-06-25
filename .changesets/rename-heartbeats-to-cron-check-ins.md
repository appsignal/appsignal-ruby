---
bump: patch
type: change
---

Rename heartbeats to cron check-ins. Calls to `Appsignal.heartbeat` and `Appsignal::Heartbeat` should be replaced with calls to `Appsignal::CheckIn.cron` and `Appsignal::CheckIn::Cron`, for example:

```ruby
# Before
Appsignal.heartbeat("do_something") do
  do_something
end

# After
Appsignal::CheckIn.cron("do_something") do
  do_something
end
```

Calls to `Appsignal.heartbeat` and `Appsignal::Heartbeat` will emit a deprecation warning.
