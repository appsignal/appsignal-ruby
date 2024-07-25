---
bump: patch
type: fix
---

Fix the default env and root path for the integrations using loader mechanism. If `APPSIGNAL_APP_ENV` is set when using `Appsignal.load(...)`, the AppSignal env set in `APPSIGNAL_APP_ENV` is now leading again.
