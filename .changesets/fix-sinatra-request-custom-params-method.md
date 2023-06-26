---
bump: "patch"
type: "fix"
---

Fix Sinatra request custom request parameters method. If the Sinatra option `params_method` is set, a different method than `params` will be called on the request object to fetch the request parameters. This can be used to add custom filtering to parameters recorded by AppSignal.
