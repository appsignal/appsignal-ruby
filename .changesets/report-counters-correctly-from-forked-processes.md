---
bump: patch
type: fix
---

In collector mode, report counter metrics correctly from processes forked after AppSignal starts, such as Puma workers when using `preload_app!`. Before this change, applications running several forked processes would lose data points or report incorrect values for them.
