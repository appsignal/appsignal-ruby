---
bump: patch
type: change
---

Instrument the entire Sinatra request. Instrumenting Sinatra apps using `require "appsignal/integrations/sinatra"` will now report more of the request, if previously other middleware were not instrumented. It will also report the response status with the `response_status` tag and metric.
