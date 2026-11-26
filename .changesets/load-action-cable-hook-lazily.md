---
bump: patch
type: fix
---

Install the Action Cable instrumentation when Rails loads `ActionCable::Channel::Base`, instead of loading the class during app initialization. This removes the ":action_cable_channel was loaded before application initialization" warning on Rails 8.2.
