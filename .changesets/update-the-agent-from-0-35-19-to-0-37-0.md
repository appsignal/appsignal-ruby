---
bump: patch
type: change
integrations: ruby
---

Update the agent from version 0.35.19 to version 0.37.0. The 3.x series of the Ruby gem was several agent releases behind, so this update also brings the improvements from every agent release in between. Those include better sanitisation of SQL queries, host metric collection that keeps working when a disk mount is frozen, and no more leftover `[timeout]` processes on Alpine Linux containers.
