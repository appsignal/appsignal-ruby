---
bump: patch
type: change
---

When the minutely probes thread takes more than 60 seconds to run all the registered probes, log an error. This helps find issues with the metrics reported by the probes not being accurately reported for every minute.
