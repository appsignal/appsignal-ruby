---
bump: patch
type: change
---

Report Global VM Lock metrics per process. In addition to the existing `hostname` tag, add `process_name` and `process_id` tags to the `gvl_global_timer` and `gvl_waiting_threads` metrics emitted by the [GVL probe](https://docs.appsignal.com/ruby/integrations/global-vm-lock.html), allowing these metrics to be tracked in a per-process basis.
