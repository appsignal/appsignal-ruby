---
bump: minor
type: change
---

Do not report error causes if the wrapper error has already been reported. This deduplicates errors and prevents the error wrapper and error cause to be reported separately, as long as the error wrapper is reported first.

```ruby
error_wrapper = nil
error_cause = nil
begin
  begin
    raise StandardError, "error cause"
  rescue => e
    error_cause = e
    raise Exception, "error wrapper"
  end
rescue Exception => e
  error_wrapper = e
end

Appsignal.report_error(error_wrapper) # Reports error
Appsignal.report_error(error_cause) # Doesn't report error
```
