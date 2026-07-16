---
bump: patch
type: fix
---

Complete the transaction even when a block handed to it raises.

The error block given to `Appsignal.send_error` and `Appsignal.report_error`, and the internal `after_create` and `before_complete` hooks, are user code that can raise. An error block runs at completion in agent mode, and the hooks run during creation and completion, so these blocks run far from where they were defined.

Until now, an exception from any of these blocks propagated out of transaction creation or completion. That surfaced the error in unrelated code, and it could leave the transaction unfinished. These blocks are now run defensively. The failure is logged, naming the error and where the block was defined, and creation and completion carry on.
