---
bump: minor
type: add
---

Add `config/appsignal.rb` config file support. When a `config/appsignal.rb` file is present in the app, the Ruby gem will automatically load it when `Appsignal.start` is called.

The `config/appsignal.rb` config file is a replacement for the `config/appsignal.yml` config file. When both files are present, only the `config/appsignal.rb` config file is loaded when the configuration file is automatically loaded by AppSignal  when the configuration file is automatically loaded by AppSignal.

Example `config/appsignal.rb` config file:

```ruby
# config/appsignal.rb
Appsignal.configure do |config|
  config.name = "My app name"
end
```

To configure different option values for environments in the `config/appsignal.rb` config file, use if-statements:

```ruby
# config/appsignal.rb
Appsignal.configure do |config|
  config.name = "My app name"
  if config.env == "production"
    config.ignore_actions << "My production action"
  end
  if config.env == "staging"
    config.ignore_actions << "My staging action"
  end
end
```
