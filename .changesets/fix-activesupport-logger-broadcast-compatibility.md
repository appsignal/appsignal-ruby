---
bump: "patch"
type: "fix"
---

Fixed a bug that prevented log messages from getting to AppSignal when using the convenience methods as in:

```ruby
Rails.logger.warn("Warning message")
```
