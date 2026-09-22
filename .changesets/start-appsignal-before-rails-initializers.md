---
bump: patch
type: fix
---

Start AppSignal before the Rails application's initializers run. Depending on
the order in which gems were loaded, AppSignal could start after
`config/initializers`. In those applications `Appsignal.active?` returned
`false` inside an initializer, errors raised by initializers were not reported,
and with `config.appsignal.start_at = :after_initialize` the Rails defaults for
`log_path` and `ignore_actions` were not applied.
