---
bump: minor
type: add
---

Add `Appsignal.configure` method of configuring AppSignal. This new method allows apps to configure AppSignal in Ruby.

```ruby
# The environment will be auto detected
Appsignal.configure do |config|
  config.activejob_report_errors = "discard"
  config.sidekiq_report_errors = :discard
  config.ignore_actions = ["My ignored action", "My other ignored action"]
  config.request_headers << "MY_HTTP_HEADER"
  config.send_params = true
  config.enable_host_metrics = false
end

# Explicitly define which environment to start
Appsignal.configure(:production) do |config|
  # Some config
end
```

If apps use the `Appsignal.config = Appsignal::Config.new(...)` way of configuring AppSignal, they should be updated to use the new `Appsignal.configure` method. The `Appsignal::Config.new` method would overwrite the given "initial config" with the config file's config and config read from environment variables. The `Appsignal.configure` method is leading. The config file, environment variables and `Appsignal.configure` methods can all be mixed.

See [our configuration guide](https://docs.appsignal.com/ruby/configuration.html) for more information.
