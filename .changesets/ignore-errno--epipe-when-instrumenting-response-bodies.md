---
bump: patch
type: change
---

Ignore `Errno::EPIPE` errors when instrumenting response bodies. We've noticed this error gets reported when the connection is broken between server and client. This happens in normal scenarios so we'll ignore this error in this scenario to avoid error reports from errors that cannot be resolved.
