---
bump: patch
type: fix
---

In collector mode, ignore a custom metric whose name OpenTelemetry does not
accept, such as a name with spaces or non-ASCII characters, and log a warning,
instead of raising an error in the application.
