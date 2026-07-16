---
bump: patch
type: fix
---

In collector mode, drop a transaction that never set an action name instead of reporting it under the placeholder `appsignal.transaction <namespace>` action. A request that is not routed to an action -- for example a static asset served without a controller -- has no action to group by. Agent mode does not report such a transaction, but collector mode was surfacing every one of them under a single shared placeholder action. The transaction's root span is now flagged with `appsignal.ignore_subtrace` on completion, so the AppSignal Collector (0.10.0 and newer) drops it, matching agent mode.
