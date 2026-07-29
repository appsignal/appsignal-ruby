---
bump: patch
type: fix
---

Fix a rare hang when stopping AppSignal in an application that sends check-ins.
Stopping AppSignal waits for any check-in events that have not been transmitted
yet, and it could wait forever instead of finishing.
