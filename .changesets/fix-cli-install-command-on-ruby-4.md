---
bump: patch
type: fix
---

Fix the `bundle exec appsignal install` CLI command on Ruby 4 by removing the dependency on the `ostruct` gem, which is no longer part of the standard library.
