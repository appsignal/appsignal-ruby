---
bump: "patch"
---

Drop logger level to debug. Reduce the output on the "info" level and only show
these messages in debug mode. This should reduce the noise for users running
AppSignal with the STDOUT logger, such as is the default on Heroku.
