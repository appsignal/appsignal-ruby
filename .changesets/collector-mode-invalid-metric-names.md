---
bump: patch
type: fix
---

In collector mode, ignore a custom metric whose name OpenTelemetry does not
accept, such as a name with spaces or non-ASCII characters, instead of raising
an error in the application.  Agent mode already ignores these names silently.
