---
bump: patch
type: add
---

Log where `Appsignal.configure` is called. When a warning is emitted about `Appsignal.configure` being called from an application where `config/appsignal.yml` or `config/appsignal.rb` exist, log the location from which `Appsignal.configure` was called alongside the location of the configuration file.