---
bump: major
type: change
---

Global transaction metadata helpers now work inside the `Appsignal.report_error` and `Appsignal.send_error` callbacks. The transaction yield parameter will continue to work, but we recommend using the global `Appsignal.set_*` and `Appsignal.add_*` helpers.

```ruby
# Before
Appsignal.report_error(error) do |transaction|
  transaction.set_namespace("my namespace")
  transaction.set_action("my action")
  transaction.add_tags(:tag_a => "value", :tag_b => "value")
  # etc.
end
Appsignal.send_error(error) do |transaction|
  transaction.set_namespace("my namespace")
  transaction.set_action("my action")
  transaction.add_tags(:tag_a => "value", :tag_b => "value")
  # etc.
end

# After
Appsignal.report_error(error) do
  Appsignal.set_namespace("my namespace")
  Appsignal.set_action("my action")
  Appsignal.add_tags(:tag_a => "value", :tag_b => "value")
  # etc.
end
Appsignal.send_error(error) do
  Appsignal.set_namespace("my namespace")
  Appsignal.set_action("my action")
  Appsignal.add_tags(:tag_a => "value", :tag_b => "value")
  # etc.
end
```
