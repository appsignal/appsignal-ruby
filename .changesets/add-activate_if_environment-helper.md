---
bump: patch
type: add
---

Add `activate_if_environment` helper for `Appsignal.configure`. Avoid having to add conditionals to your configuration file and use the `activate_if_environment` helper to specify for which environments AppSignal should become active. AppSignal will automatically detect the environment and activate itself it the environment matches one of the listed environments.

```ruby
# Before
Appsignal.configure do |config|
  config.active = Rails.env.production? || Rails.env.staging?
end

# After
Appsignal.configure do |config|
  # Activate for one environment
  config.activate_if_environment(:production)

  # Activate for multiple environments
  config.activate_if_environment(:production, :staging)
end
```
