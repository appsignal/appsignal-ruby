---
bump: minor
type: fix
---

Support streaming bodies. AppSignal's Rack instrumentation now supports streaming bodies in responses, such as those produced by `Async::Cable`. This fixes an issue where AppSignal's Rack instrumentation would cause requests with streaming bodies to crash.

If you use our Rack instrumentation through a framework that is automatically instrumented by AppSignal, such as Rails, Hanami, Padrino or Sinatra, this fix is applied automatically.

If your application instruments Rack manually, you must remove the following line from your application's initial setup:

```ruby
use Rack::Events, [Appsignal::Rack::EventHandler.new]
```

And replace it with the following line:

```ruby
use Appsignal::Rack::EventMiddleware
```
