---
bump: patch
type: add
---

Support Rails/ActiveSupport tagged logging. When tags are set in apps using `Rails.logger.tagged { ... }` or with the `Rails.application.config.log_tags = [...]` config option, these tags are now included in the collected log messages.

```ruby
Rails.logger.tagged(["Tag 1", "Tag 2"]) { Rails.logger.info("My message") }
```

Reports this log message:

> [Tag 1] [Tag 2] My message
