---
bump: patch
type: fix
---

Fix an issue where a web request or Action Cable action could be reported with
data from an earlier request processed on the same thread.  When AppSignal could
not finish recording a request, the next request or action on that thread was
reported under the earlier request's action name, with its parameters and
errors, and with a duration that was too long.

The data of the unfinished request is now discarded, and a warning is logged in
the AppSignal log.
