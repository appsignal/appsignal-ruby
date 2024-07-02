---
bump: minor
type: add
---

Add our new recommended Rack instrumentation middleware. If an app is using the `Appsignal::Rack::GenericInstrumentation` middleware, please update it to use `Appsignal::Rack::InstrumentationMiddleware` instead.

This new middleware will not report all requests under the "unknown" action if no action name is set. To set an action name, call the `Appsignal.set_action` helper from the app.

```ruby
# config.ru

# Setup AppSignal

use Appsignal::Rack::InstrumentationMiddleware

# Run app
```
