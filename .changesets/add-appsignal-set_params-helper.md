---
bump: patch
type: add
---

Add `Appsignal.set_params` helper. Set custom parameters on the current transaction with the `Appsignal.set_params` helper. Note that this will overwrite any request parameters that would be set automatically on the transaction. When this method is called multiple times, it will overwrite the previously set value.

```ruby
Appsignal.set_params("param1" => "value1", "param2" => "value2")
```
