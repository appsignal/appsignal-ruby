---
bump: minor
type: change
---

Remove the HTTP gem's exception handling. Errors from the HTTP gem will no longer always be reported. The error will be reported only when an HTTP request is made in an instrumented context. This gives applications the opportunity to add their own custom exception handling.

```ruby
begin
  HTTP.get("https://appsignal.com/error")
rescue => error
  # Either handle the error or report it to AppSignal
end
```
