---
bump: patch
type: fix
---

Fix issue with AppSignal getting stuck in a boot loop when loading the Padrino integration with: `require "appsignal/integrations/padrino"`
This could happen in nested applications, like a Padrino app in a Rails app. AppSignal will now use the first config AppSignal starts with.
