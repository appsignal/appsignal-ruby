---
bump: patch
type: add
---

Support adding multiple errors to a transaction.

Using the `Appsignal.report_error` helper, you can now report more than one error within the same transaction context, up to a maximum of ten errors per transaction. Each error will be reported as a separate sample in the AppSignal UI.

Before this change, using `Appsignal.report_error` or `Appsignal.set_error` helpers, adding a new error within the same transaction would overwrite the previous one.
