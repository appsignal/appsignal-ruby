---
bump: "patch"
type: "add"
---

Add option to `activejob_report_errors` option to only report errors when a job is discard by Active Job. In the example below the job is retried twice. If it fails with an error twice the job is discarded. If `activejob_report_errors` is set to `discard`, you will only get an error reported when the job is discarded. This new `discard` value only works for Active Job 7.1 and newer.


```ruby
class ExampleJob < ActiveJob::Base
  retry_on StandardError, :attempts => 2

  # ...
end
```
