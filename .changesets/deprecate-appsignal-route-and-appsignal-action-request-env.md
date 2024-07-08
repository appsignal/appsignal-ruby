---
bump: patch
type: deprecate
---

Deprecate the `appsignal.action` and `appsignal.route` request env methods to set the transaction action name. Use the `Appsignal.set_action` helper instead.

```ruby
# Before
env["appsignal.action"] = "POST /my-action"
env["appsignal.route"] = "POST /my-action"

# After
Appsignal.set_action("POST /my-action")
```
