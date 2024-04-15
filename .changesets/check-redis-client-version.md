---
bump: "patch"
type: "fix"
---

Check the redis-client gem version before installing instrumentation. This prevents errors from being raised on redis-client gem versions older than 0.14.0.
