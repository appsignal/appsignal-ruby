---
bump: patch
type: change
---

Send check-ins concurrently. When calling `Appsignal::CheckIn.cron`, instead of blocking the current thread while the check-in events are sent, schedule them to be sent in a separate thread.

When shutting down your application manually, call `Appsignal.stop` to block until all scheduled check-ins have been sent.
