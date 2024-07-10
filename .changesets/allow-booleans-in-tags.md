---
bump: patch
type: change
---

Allow tags to have boolean (true/false) values.

```ruby
Appsignal.set_tags("my_tag_is_amazing" => true)
Appsignal.set_tags("my_tag_is_false" => false)
```
