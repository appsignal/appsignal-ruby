---
bump: patch
type: fix
---

Install the Action Cable instrumentation in an `on_load(:action_cable_channel)` hook. Rails 8.2 logs ":action_cable_channel was loaded before application initialization" when AppSignal loads `ActionCable::Channel::Base` while the app boots, and that warning no longer appears.
