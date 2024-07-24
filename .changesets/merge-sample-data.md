---
bump: major
type: change
---

The transaction sample data is now merged by default. Previously, the sample data (except for tags) would be overwritten when an `Appsignal.set_*` helper was called.

```ruby
# Old behavior
Appsignal.set_params("param1" => "value")
Appsignal.set_params("param2" => "value")
# The parameters are:
# { "param2" => "value" }


# New behavior
Appsignal.add_params("param1" => "value")
Appsignal.add_params("param2" => "value")
# The parameters are:
# {  "param1" => "value", "param2" => "value" }
```

New helpers have been added:

- `Appsignal.add_tags`
- `Appsignal.add_params`
- `Appsignal.add_session_data`
- `Appsignal.add_headers`
- `Appsignal.add_custom_data`

The old named helpers that start with `set_` will still work. They will also use the new merging behavior.
