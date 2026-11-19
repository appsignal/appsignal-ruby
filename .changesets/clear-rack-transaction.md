---
bump: patch
type: fix
---

Fix different requests on the same thread from being reported as one.  When
processing a new request, the Rack integration (used by the Rails, Hanami,
Padrino and Sinatra integrations) would reuse an existing transaction, left-over by the previous request.  
Now, new requests close the existing transaction and start a new one.
