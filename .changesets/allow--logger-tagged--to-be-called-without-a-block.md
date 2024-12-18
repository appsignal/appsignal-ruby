---
bump: patch
type: fix
---

Allow `Appsignal::Logger#tagged` to be called without a block, in the same way as `ActiveSupport::TaggedLogging`:

```ruby
Appsignal::Logger.new("rails").tagged("some tag").info("message")
# => logs "[some tag] message"
```
