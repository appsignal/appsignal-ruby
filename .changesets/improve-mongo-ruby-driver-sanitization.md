---
bump: "patch"
type: "change"
---

The MongoDB query sanitization now shows all the attributes in the query at all levels.
Only the actual values are filtered with a `?` character. Less MongoDB queries are now marked
as N+1 queries when they weren't the exact same query. This increases the number of unique events
AppSignal tracks for MongoDB queries.
