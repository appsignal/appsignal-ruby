---
bump: patch
type: add
---

Detect the hostname of the machine the application runs on. On Heroku this is the name of the dyno, and everywhere else it is the name the host reports for itself. Set the `hostname` configuration option to report a different name.

This affects collector mode, where all data was reported for a host named `unknown` when the hostname was not configured.
