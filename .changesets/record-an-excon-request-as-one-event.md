---
bump: minor
type: change
---

Fix Excon requests being reported as taking almost no time. An Excon request was
recorded as two events, one for sending the request and one for reading the
response, and neither of them covered the wait for the remote service. So a slow
Excon request looked fast in the event timeline, however long it really took.

An Excon request is now recorded as a single `request.excon` event covering the
whole request, so the event lasts as long as the request did. A request that
Excon retried, or that was redirected, is also one event, covering every attempt
or every hop.

The `response.excon`, `retry.excon` and `error.excon` events no longer exist.
Excon does not tell an instrumentor which request those events belonged to, so
`response.excon` never had a title and `error.excon` was always titled `" ://"`.

AppSignal also no longer registers itself as Excon's instrumentor. Excon allows
only one instrumentor, so an application that set up its own was having it
replaced. Your own instrumentor now keeps working.
