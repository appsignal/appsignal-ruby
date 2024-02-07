---
bump: "patch"
type: "change"
---

Default headers don't contain `REQUEST_URI` anymore as query params are not filtered. Now `REQUEST_PATH` is sent instead to avoid any PII filtering.
