---
bump: minor
type: change
---

Report the time spent in Rails middleware as part of the request duration. The AppSignal Rack middleware is now higher in the middleware stack and reports more time of the request to give insights in how long other middleware took. This is reported under the new `process_request.rack` event in the event timeline.
