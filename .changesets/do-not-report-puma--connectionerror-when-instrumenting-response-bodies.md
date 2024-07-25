---
bump: patch
type: change
---

Do not report `Puma::ConnectionError` when instrumenting response bodies to avoid reporting errors that cannot be fixed by the application.
