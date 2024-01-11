---
bump: "patch"
type: "deprecate"
---

Deprecate the `Appsignal.set_host_guage` and `Appsignal.set_process_gauge` helper methods in the Ruby gem. These methods would already log deprecation warnings in the `appsignal.log` file, but now also as a Ruby warning. These methods will be removed in the next major version. These methods already did not report any metrics, and still do not.
