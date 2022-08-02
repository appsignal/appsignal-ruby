---
bump: "patch"
type: "fix"
---

Fix error on unknown HTTP request method. When a request is made with an unknown request method, triggering and `ActionController::UnknownHttpMethod`, it will no longer break the AppSignal instrumentation but omit the request method in the sample data.
