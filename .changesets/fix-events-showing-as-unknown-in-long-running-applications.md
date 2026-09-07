---
bump: patch
type: fix
integrations:
- ruby
---

Fix events showing as unknown in long-running applications. An application process that kept running for thirty days without restarting could lose the names and queries of the events it recorded, both in slow traces and in the "Slow events" panel.
