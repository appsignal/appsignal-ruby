---
bump: patch
type: fix
---

Fix instrument events for response bodies appearing twice. When multiple instrumentation middleware were mounted in an application, it could create duplicate `process_response_body.rack` events.
