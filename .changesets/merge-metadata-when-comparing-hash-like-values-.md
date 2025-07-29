---
bump: patch
type: fix
---

When a Hash-like value (such as `ActiveSupport::HashWithIndifferentAccess` or `Sinatra::IndifferentHash`) is passed to a transaction helper (such as `add_params`, `add_session_data`, ...) it is now converted to a Ruby `Hash` before setting it as the value or merging it with the existing value. This allows Hash-like objects to be merged, instead of logging a warning and only storing the new value.

```ruby
# Example scenario
Appsignal.add_params(:key1 => { :abc => "value" })
Appsignal.add_params(ActiveSupport::HashWithIndifferentAccess.new(:key2 => { :def => "value" }))

# Params
{
  :key1 => { :abc => "value" },
  # Keys from HashWithIndifferentAccess are stored as Strings
  "key2" => { "def" => "value" }
}
```
