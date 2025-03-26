---
bump: patch
type: deprecate
---

Deprecate the `Appsignal.monitor_and_stop` helper.

We instead recommend using the `Appsignal.monitor` helper and configuring the `enable_at_exit_hook` config option to `always`.
