---
bump: patch
type: change
---

Specify stricter Rack version requirement. The Ruby gem relies on the `Rack::Events` constant which was introduced in Rack 2. Update our version requirement to require Rack 2 or newer.
