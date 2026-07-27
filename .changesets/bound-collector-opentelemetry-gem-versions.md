---
bump: patch
type: change
---

Collector mode now checks the installed OpenTelemetry gems against both a lower and an upper version bound. Before, it only required a minimum version. The upper bound is a pessimistic constraint at the next major version. It is set loosely on purpose so it does not block you from updating these gems within a major version.

When the OpenTelemetry gems collector mode needs are missing or installed at an unsupported version, the warning now recommends adding the `appsignal-opentelemetry` gem to install them. It only lists specific gems when they are installed at a version collector mode does not support, because that usually points to a version constraint in your bundle that the `appsignal-opentelemetry` gem cannot override on its own.
