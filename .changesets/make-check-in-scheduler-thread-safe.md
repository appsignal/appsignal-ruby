---
bump: patch
type: fix
---

Fix a thread safety issue where sending check-in events simultaneously from different threads would cause several check-in schedulers to be initialised internally. This could cause some of the scheduled check-in events to never be sent to AppSignal when `Appsignal.stop` is called.
