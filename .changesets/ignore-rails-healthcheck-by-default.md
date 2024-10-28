---
bump: patch
type: change
---

Ignore the Rails healthcheck endpoint (Rails::HealthController#show) by default for Rails apps.

If the `ignore_actions` option is set in the `config/appsignal.yml` file, the default is overwritten.
If the `APPSIGNAL_IGNORE_ACTIONS` environment variable is set, the default is overwritten.
When using the `Appsignal.configure` helper, add more actions to the default like so:

```ruby
# config/appsignal.rb
Appsignal.configure do |config|
  # Add more actions to ignore
  config.ignore_actions << "My action"
end
```

To overwrite the default using the `Appsignal.configure` helper, do either of the following:

```ruby
# config/appsignal.rb
Appsignal.configure do |config|
  # Overwrite the default value, ignoring all actions ignored by default
  config.ignore_actions = ["My action"]

  # To only remove the healtcheck endpoint
  config.ignore_actions.delete("Rails::HealthController#show")
end
```
