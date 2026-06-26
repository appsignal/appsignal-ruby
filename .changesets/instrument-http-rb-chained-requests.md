---
bump: patch
type: fix
---

Instrument HTTP.rb chained requests on http 6. Requests made through a chained
client -- `HTTP.follow.get(...)`, `HTTP.headers(...).get(...)`, and so on -- go
through `HTTP::Session` rather than `HTTP::Client`, and were not being recorded.
They now produce a `request.http_rb` event like any other request.
