---
bump: "patch"
type: "add"
---

Add `filter_metadata` config option to filter metadata set on Transactions set by default. Metadata like `path`, (request)  `method`, `request_id`, `hostname`, etc. This can be useful if there's PII or other sensitive data in any of the app's metadata.
