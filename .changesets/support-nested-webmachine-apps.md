---
bump: patch
type: add
---

Support nested webmachine apps. If webmachine apps are nested in other AppSignal instrumentation it will now report the webmachine instrumentation as part of the parent transaction, reporting more runtime of the request.
