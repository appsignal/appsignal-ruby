---
bump: major
type: remove
---

Remove the `Appsignal.listen_for_error` helper. Use manual exception handling using `rescue => error` with the `Appsignal.report_error` helper instead.
