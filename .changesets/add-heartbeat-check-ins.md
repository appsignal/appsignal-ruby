---
bump: minor
type: add
---

Add support for heartbeat check-ins.

Use the `Appsignal::CheckIn.heartbeat` method to send a single heartbeat check-in event from your application. This can be used, for example, in your application's main loop:

```ruby
loop do
  Appsignal::CheckIn.heartbeat("job_processor")
  process_job
end
```

Heartbeats are deduplicated and sent asynchronously, without blocking the current thread. Regardless of how often the `.heartbeat` method is called, at most one heartbeat with the same identifier will be sent every ten seconds.

Pass `continuous: true` as the second argument to send heartbeats continuously during the entire lifetime of the current process. This can be used, for example, after your application has finished its boot process:

```ruby
def main
  start_app
  Appsignal::CheckIn.heartbeat("my_app", continuous: true)
end
```
