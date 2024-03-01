---
bump: "patch"
type: "add"
---

Add `activejob_report_errors` config option. When set to `"none"`, ActiveJob jobs will no longer report errors. This can be used in combination with [custom exception reporting](https://docs.appsignal.com/ruby/instrumentation/exception-handling.html). By default, the config option has the value `"all"`, which reports all errors.
