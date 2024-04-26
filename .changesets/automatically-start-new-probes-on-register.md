---
bump: "patch"
type: "change"
---

Automatically start new probes when registered with `Appsignal::Probes.register` when the gem has already started the probes thread. Previously, the late registered probes would not be run.
