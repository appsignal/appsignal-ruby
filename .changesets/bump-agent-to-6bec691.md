---
bump: "patch"
type: "change"
---

Bump agent to 6bec691.

- Upgrade `sql_lexer` to v0.9.5. It adds sanitization support for the `THEN` and `ELSE` logical operators.
- Only ignore disk metrics that start with "loop", not all mounted disks that end with a number to report metrics for more disks.
- Rely on APPSIGNAL_RUNNING_IN_CONTAINER config option value before other environment factors to determine if the app is running in a container.
- Fix container detection for hosts running Docker itself.
- Add APPSIGNAL_STATSD_PORT config option.
