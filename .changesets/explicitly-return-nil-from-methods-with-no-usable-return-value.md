---
bump: patch
type: change
---

Explicitly return `nil` from public methods with no usable return value. We want to avoid the situation where `Appsignal.start` happens to return `true` and it is thought to mean that the gem started successfully.

Methods updated:

- `Appsignal.start`
- `Appsignal.stop`
- `Appsignal.configure`
- `Appsignal.forked`
- `Appsignal.load`
