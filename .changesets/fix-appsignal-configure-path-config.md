---
bump: patch
type: fix
---

Fix the `Appsignal.configure` path config not being customizable. It's now possible to pass a `root_path` keyword argument to `Appsignal.configure` to customize the path from which AppSignal reads the config file, `config/appsignal.yml`.
