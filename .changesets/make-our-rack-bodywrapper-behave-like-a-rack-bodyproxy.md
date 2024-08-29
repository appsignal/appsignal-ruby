---
bump: patch
type: fix
---

Make our Rack BodyWrapper behave like a Rack BodyProxy. If a method doesn't exist on our BodyWrapper class, but it does exist on the body, behave like the Rack BodyProxy and call the method on the wrapped body.
