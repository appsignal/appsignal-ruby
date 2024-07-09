---
bump: patch
type: add
---

Add `Appsignal.set_session_data` helper. Set custom session data on the current transaction with the `Appsignal.set_session_data` helper. Note that this will overwrite any request session data that would be set automatically on the transaction. When this method is called multiple times, it will overwrite the previously set value.

```ruby
Appsignal.set_session_data("data1" => "value1", "data2" => "value2")
```
