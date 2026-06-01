---
bump: patch
type: fix
---

Prevent a `NoMethodError` in the Active Job, Rake, Sidekiq, Delayed Job, and WebMachine instrumentations when the creation of an AppSignal transaction is interrupted by process shutdown signals.
