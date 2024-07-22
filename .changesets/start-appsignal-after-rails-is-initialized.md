---
bump: minor
type: add
---

Add a Rails configuration option to start AppSignal after Rails is initialized. By default, AppSignal will start before the Rails initializers are run. This way it is not possible to configure AppSignal in a Rails initializer using Ruby. To configure AppSignal in a Rails initializer, configure Rails to start AppSignal after it is initialized.

```ruby
# config/application.rb

# ...

module MyApp
  class Application < Rails::Application
    # Add this line
    config.appsignal.start_at = :after_initialize

    # Other config
  end
end
```

Then, in the initializer:

```ruby
# config/initializers/appsignal.rb

Appsignal.config = Appsignal::Config.new(
  Rails.root,
  Rails.env,
  :ignore_actions => ["My action"]
)
```

Be aware that when `start_at` is set to `after_initialize`, AppSignal will not track any errors that occur when the initializers are run and the app fails to start.

See [our Rails documentation](https://docs.appsignal.com/ruby/integrations/rails.html) for more information.
