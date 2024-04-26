---
bump: "patch"
type: "change"
---

Stop the minutely probes when `Appsignal.stop` is called. When `Appsignal.stop` is called, the probes thread will no longer continue running in the app process.
