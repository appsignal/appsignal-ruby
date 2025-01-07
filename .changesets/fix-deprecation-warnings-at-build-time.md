---
bump: patch
type: fix
---

Fix deprecation warnings when building the AppSignal gem's native extension on Ruby 3.4, by porting the extension to use the TypedData API.
