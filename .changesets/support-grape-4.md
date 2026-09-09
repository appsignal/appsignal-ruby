---
bump: patch
type: add
---

Add support for Grape 4. On Grape 4, every request through a Grape API raised a `NoMethodError`. Applications on Grape 3 and below were not affected.

On Grape 4, the action name and the reported path now describe the endpoint's full route, so they include the API prefix, the path version and the mount point. They also no longer end in a trailing slash when the endpoint declares no path of its own, so an endpoint reported as `GET::My::Api#/users/:id/` is now reported as `GET::My::Api#/users/:id`. Action names on Grape 3 and below do not change.
