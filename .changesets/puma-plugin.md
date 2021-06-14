---
bump: "patch"
---

Improve Puma plugin stats collection. Instead of starting the AppSignal gem in the main process we send the stats to the AppSignal agent directly using StatsD. This should improve compatibility with phased restarts. If you use `prune_bundler`, you will need to add AppSignal to the extra `extra_runtime_dependencies` list.

```
# config/puma.rb
plugin :appsignal
extra_runtime_dependencies ["appsignal"]
```
