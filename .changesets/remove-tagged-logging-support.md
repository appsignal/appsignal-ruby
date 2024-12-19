---
bump: patch
type: remove
---

Remove tagged logging support from `Appsignal::Logger`.

Tagged logging is still supported by wrapping an instance of `Appsignal::Logger` with `ActiveSupport::TaggedLogging`:

```ruby
appsignal_logger = Appsignal::Logger.new("rails")
tagged_logger = ActiveSupport::TaggedLogging.new(appsignal_logger)
Rails.logger = tagged_logger
```

Removing this functionality allows for a workaround to issues within Rails ([#49745](https://github.com/rails/rails/issues/49745), [#51883](https://github.com/rails/rails/issues/51883)), where using the broadcast logger to log to more than one tagged logger results in incorrect behaviour of the tagged logging methods, resulting in breakage throughout Rails' internals:

```ruby
# We use the built-in request ID middleware as an example that triggers
# the issue:
Rails.config.log_tags = [:request_id]

appsignal_logger = Appsignal::Logger.new("rails")
tagged_logger = ActiveSupport::TaggedLogging.new(appsignal_logger)

# This does not work correctly, because the default `Rails.logger` is a
# broadcast logger that is already broadcasting to a tagged logger.
# When asked to broadcast to a second tagged logger, the return value of
# `Rails.logger.tagged { ... }` will be incorrect, in turn causing the
# `RequestID` middleware, which uses it internally, to return broken
# Rack responses.
Rails.logger.broadcast_to(tagged_logger)
```

By reverting the changes to our logger so that it is no longer a tagged logger, we enable a workaround to this issue:

```ruby
Rails.config.log_tags = [:request_id]

appsignal_logger = Appsignal::Logger.new("rails")

# This works correctly, because `appsignal_logger` is not a tagged logger.
# Note that `appsignal_logger` will not have the `request_id` tags.
Rails.logger.broadcast_to(appsignal_logger)
```
