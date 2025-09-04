---
bump: patch
type: change
---

Do not patch `Rack::Events` when using recent Rack versions. When using versions 3.2.1 and above,
which contain a fix for the bug where using `Rack::Events` breaks requests with streaming bodies,
use `Rack::Events` directly, instead of our patched subclass.
