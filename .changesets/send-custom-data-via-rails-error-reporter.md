---
bump: "patch"
type: "add"
---

Allow passing custom data using the `appsignal` context via the Rails error reporter:

```ruby
custom_data = { :hash => { :one => 1, :two => 2 }, :array => [1, 2] }
Rails.error.handle(:context => { :appsignal => { :custom_data => custom_data } }) do
  raise "Test"
end
```
