---
bump: "patch"
type: "fix"
---

Log error when the argument type of the breadcrumb metadata is invalid. This metadata argument should be a Hash, and other values are not supported. More information can be found in the [Ruby gem breadcrumb documentation](https://docs.appsignal.com/ruby/instrumentation/breadcrumbs.html).

```ruby
Appsignal.add_breadcrumb(
  "breadcrumb category",
  "breadcrumb action",
  "some message",
  { :metadata_key => "some value" } # This needs to be a Hash object
)
```
