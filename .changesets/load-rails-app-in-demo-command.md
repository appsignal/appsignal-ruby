---
bump: patch
type: fix
---

Load the host Rails application before the `appsignal demo` command reads the
AppSignal configuration. This matches the behavior of `appsignal diagnose`.

Thanks [@Guflly](https://github.com/Guflly) for your contribution!
