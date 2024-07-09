---
bump: patch
type: add
---

Add `Appsignal.set_headers` helper. Set custom request headers on the current transaction with the `Appsignal.set_headers` helper. Note that this will overwrite any request headers that would be set automatically on the transaction. When this method is called multiple times, it will overwrite the previously set value.

```ruby
Appsignal.set_headers("PATH_INFO" => "/some-path", "HTTP_USER_AGENT" => "Firefox")
```
