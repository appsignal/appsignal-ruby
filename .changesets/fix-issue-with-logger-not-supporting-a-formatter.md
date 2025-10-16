---
bump: patch
type: fix
---

Fix an issue with loggers not supporting a formatter on Rails boot. This will prevent the AppSignal logger config from running into an error if the logger configuration is added to `config/application.rb` or one of the environments in `config/environments/`.
