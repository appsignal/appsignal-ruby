---
bump: patch
type: change
---

Require the AppSignal gem in the Grape integration file. Previously `require "appsignal"` had to be called before `require "appsignal/integrations/grape"`. This `require "appsignal"` is no longer required.
