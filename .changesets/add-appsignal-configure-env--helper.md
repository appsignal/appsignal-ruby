---
bump: patch
type: add
---

Add `Appsignal.configure` context `env?` helper method. Check if the loaded environment matches the given environment using the `.env?(:env_name)` helper.

Example:

```ruby
Appsignal.configure do |config|
  # Symbols work as the argument
  if config.env?(:production)
    config.ignore_actions << "My production action"
  end

  # Strings also work as the argument
  if config.env?("staging")
    config.ignore_actions << "My staging action"
  end
end
```
