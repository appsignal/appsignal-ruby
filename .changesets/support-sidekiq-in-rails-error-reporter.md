---
bump: "patch"
type: "add"
---

Support Sidekiq in Rails error reporter. Track errors reported using `Rails.error.handle` in Sidekiq jobs, in the correct action. Previously it would report no action name for the incident, now it will use the worker name by default.
