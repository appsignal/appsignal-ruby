---
bump: "patch"
type: "add"
---

Sanitize `ActiveRecord::RecordNotUnique` error messages to not include any database values that is not unique in the database. This ensures no personal information is sent to AppSignal through error messages from this error.
