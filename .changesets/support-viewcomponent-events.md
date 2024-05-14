---
bump: "patch"
type: "add"
---

Support events emitted by ViewComponent. Rendering of ViewComponent-based components will appear as events in your performance samples' event timeline.

For AppSignal to instrument ViewComponent events, you must first configure ViewComponent to emit those events:

```ruby
# config/application.rb
module MyRailsApp
  class Application < Rails::Application
    config.view_component.instrumentation_enabled = true
    config.view_component.use_deprecated_instrumentation_name = false
  end
end
```

Thanks to Trae Robrock (@trobrock) for providing a starting point for this implementation!
