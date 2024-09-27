---
bump: patch
type: fix
---

Report all the config options set via `Appsignal.config` in the DSL config source in the diagnose report. Previously, it would only report the options from the last time `Appsignal.configure` was called.
