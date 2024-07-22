---
bump: patch
type: fix
---

Fix instrumentation events for response bodies appearing twice. When multiple instrumentation middleware were mounted in an application, it would create duplicate `process_response_body.rack` events.
