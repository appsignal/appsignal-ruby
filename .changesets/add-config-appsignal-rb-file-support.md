---
bump: minor
type: add
---

Add `config/appsignal.rb` config file support. When a `config/appsignal.rb` file is present in the app, the Ruby gem will automatically load it when `Appsignal.start` is called.

The `config/appsignal.rb` config file is a replacement for the `config/appsignal.yml` config file. When both files are present, only the `config/appsignal.rb` config file is loaded.

Example `config/appsignal.rb` config file:

```ruby
# config/appsignal.rb
Appsignal.configure do |config|
  config.name = "My app name"
end
```

It is not possible to configure multiple environments in the `config/appsignal.rb` config file as it was possible in the YAML version.
