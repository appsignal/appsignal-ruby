---
bump: "patch"
type: "add"
---

Add the `Transaction.current?` helper to determine if any Transaction is currently active or not. AppSignal `NilTransaction`s are not considered active transactions.
