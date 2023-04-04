---
bump: "patch"
type: "change"
---

Set the AppSignal transaction namespace, action name and some tags, before Active Job jobs are performed. This allows us to check what the namespace, action name and some tags are during the instrumentation itself.
