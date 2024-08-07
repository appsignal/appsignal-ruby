---
bump: patch
type: change
---

Include the config options from the loaders config defaults and the `Appsignal.configure` helper in diagnose report. The sources for config option values will include the loaders and `Appsignal.configure` helper in the output and the JSON report sent to our severs, when opted-in.
