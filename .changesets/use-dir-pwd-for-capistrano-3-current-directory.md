---
bump: "patch"
type: "fix"
---

Use `Dir.pwd` to determine the current directory in the Capistrano 3 integration. It previously relied on `ENV["pwd"]` which returned `nil` in some scenarios.
