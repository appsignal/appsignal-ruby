---
bump: patch
type: fix
---

Fix issue with AppSignal getting stuck in a boot loop when loading the Hanami integration with: `require "appsignal/integrations/hanami"`
This could happen in nested applications, like a Hanami app in a Rails app. It will now use the first config AppSignal starts with.
