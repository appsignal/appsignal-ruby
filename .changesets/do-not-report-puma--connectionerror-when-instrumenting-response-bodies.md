---
bump: patch
type: change
---

Do not report errors caused by `Errno::EPIPE` (broken pipe errors) when instrumenting response bodies, to avoid reporting errors that cannot be fixed by the application.
