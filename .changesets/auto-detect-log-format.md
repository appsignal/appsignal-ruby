---
bump: patch
type: change
---

Detect the log format automatically. We now detect if a log line is in the JSON, Logfmt or plaintext formats. No further config needed when calling our logger, like so:

```ruby
logger = Appsignal::Logger.new("gruop")
logger.info("message")
```
