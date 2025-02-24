---
bump: patch
type: fix
---

Validate application environment sources so nil values and empty strings are not valid app environments.
Symbols are now always cast to a String before set as the application environment.

```ruby
# These will no longer be accepted as valid app environments
Appsignal.configure("")
Appsignal.configure(" ")
```
