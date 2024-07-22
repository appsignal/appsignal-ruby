---
bump: minor
type: change
---

Update the Sinatra, Padrino, Grape and Hanami integration setup for applications. Before this change a "appsignal/integrations/sinatra" file would need to be required to load the AppSignal integration for Sinatra. Similar requires exist for other libraries. This has changed to a new integration load mechanism.

This new load mechanism makes starting AppSignal more predictable when loading multiple integrations, like those for Sinatra, Padrino, Grape and Hanami.

```ruby
# Sinatra example
# Before
require "appsignal/integrations/sinatra"

# After
require "appsignal"

Appsignal.load(:sinatra)
Appsignal.start
```

The `require "appsignal/integrations/sinatra"` will still work, but is deprecated in this release.

See the documentation for the specific libraries for the latest on how to integrate AppSignal.

- [Grape](https://docs.appsignal.com/ruby/integrations/grape.html)
- [Hanami](https://docs.appsignal.com/ruby/integrations/hanami.html)
- [Padrino](https://docs.appsignal.com/ruby/integrations/padrino.html)
- [Sinatra](https://docs.appsignal.com/ruby/integrations/sinatra.html)

When using a combination of the libraries listed above, read our [integration guide](https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html) on how to load and configure AppSignal for multiple integrations at once.
