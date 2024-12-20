---
bump: minor
type: add
---

Add logger broadcasting. This change implements an alternative within `Appsignal::Logger` to `ActiveSupport::BroadcastLogger`, following the same interface. This enables a proper workaround to the issues with `ActiveSupport::BroadcastLogger` (([#49745](https://github.com/rails/rails/issues/49745), [#51883](https://github.com/rails/rails/issues/51883))) when used alongside tagged logging.

For example, to use tagged logging both in logs emitted by the default `Rails.logger` and in logs sent to AppSignal, replace the `Rails.logger` with an AppSignal logger that broadcasts to the default `Rails.logger`:

```ruby
appsignal_logger = Appsignal::Logger.new("app")
appsignal_logger.broadcast_to(Rails.logger)
Rails.logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
```
