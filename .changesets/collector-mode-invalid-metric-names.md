---
bump: patch
type: fix
---

In collector mode, drop a custom metric whose name OpenTelemetry does not
accept, such as a name with spaces or non-ASCII characters, instead of raising
an error in the application.
