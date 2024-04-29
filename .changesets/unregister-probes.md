---
bump: "patch"
type: "change"
---

Allow unregistering minutely probes. Use `Appsignal::Probes.unregister` to unregister probes registered with `Appsignal::Probes.register` if you do not need a certain probe, including default probes.
