---
bump: "patch"
type: "fix"
---

Fix sanitized values wrapped in Arrays. When a value like `[{ "foo" => "bar" }]` was sanitized it would be stored as `{ "foo" => "?" }`, omitting the parent value's Array square brackets. Now values will appear with the same structure as they were originally sanitized. This only applies to certain integrations like MongoDB, moped and ElasticSearch.
