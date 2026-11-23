---
bump: patch
type: fix
---

In collector mode, sending data to the AppSignal collector would fail if invalid
UTF-8 bytes were present, anywhere in the data structure.  Such failures would
cause the loss of the complete batch data.

This change ensures that valid UTF-8 strings are used by replacing the invalid
bytes with `�`.

Also, custom metrics are now rejected if their names are not in accordance with
OpenTelemetry's standard.  When that happens a log issued.
