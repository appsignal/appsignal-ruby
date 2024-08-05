---
bump: major
type: change
---

Set the Rails config defaults for `Appsignal.configure` when used in a Rails initializer. Now when using `Appsignal.configure` in a Rails initializer, the Rails env and root path are set on the AppSignal config as default values and do not need to be manually set.
