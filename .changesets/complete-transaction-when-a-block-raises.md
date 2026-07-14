---
bump: patch
type: fix
---

Complete the transaction even when a block handed to it raises. The error block passed to `Appsignal.set_error`, `Appsignal.send_error`, and `Appsignal.report_error`, as well as the internal `after_create` and `before_complete` hooks, are user code that can raise. Until now such an exception propagated out of transaction creation or completion, which surfaced the error in unrelated code and could leave the transaction unfinished. These blocks are now run defensively: the failure is logged, naming the error and where the block was defined, and creation and completion carry on.
