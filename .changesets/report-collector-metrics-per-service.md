---
bump: patch
type: fix
---

In collector mode, report allocation counts and queue durations per service and namespace. This fixes an issue where these metrics were reported by namespace alone, causing the "Performance" > "Allocations" page to link to performance pages that did not exist.
