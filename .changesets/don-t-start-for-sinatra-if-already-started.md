---
bump: patch
type: fix
---

Fix issue with AppSignal getting stuck in a boot loop when loading the Sinatra integration with: `require "appsignal/integrations/sinatra"`
This could happen in nested applications, like a Sinatra app in a Rails app. It will now use the first config AppSignal starts with.
