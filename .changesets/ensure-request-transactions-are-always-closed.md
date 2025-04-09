---
bump: patch
type: fix
---

Ensure request transactions are always closed in the `Rack::EventHandler`. A problem with Fibers changing during a request would cause transactions transactions to be left open and the data from requests to not be sent to our servers.
