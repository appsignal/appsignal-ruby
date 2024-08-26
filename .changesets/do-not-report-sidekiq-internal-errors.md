---
bump: patch
type: change
---

Do not report Sidekiq `Sidekiq::JobRetry::Handled` and `Sidekiq::JobRetry::Skip` errors. These errors would be reported by our Rails error subscriber. These are an internal Sidekiq errors we do not need to report.
