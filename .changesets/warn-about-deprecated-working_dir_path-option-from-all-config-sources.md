---
bump: "patch"
type: "deprecate"
---

Warn about the deprecated `working_dir_path` option from all config sources. It previously only printed a warning when it was configured in the `config/appsignal.yml` file, but now also prints the warning if it's set via the Config class initialize options and environment variables. Please use the `working_directory_path` option instead.
