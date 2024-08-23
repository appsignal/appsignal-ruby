---
bump: patch
type: fix
---

Do not report `Sidekiq::JobRetry::Skip` errors. These errors would be reported by our Rails error subscriber. This is an internal Sidekiq error we do not need to report.
