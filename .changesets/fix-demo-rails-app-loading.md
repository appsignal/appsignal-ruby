---
bump: patch
type: fix
---

Load the host Rails application before the `appsignal demo` command reads its
configuration. This allows `config/appsignal.rb` to reference Rails application
state, matching the behavior of `appsignal diagnose`.
