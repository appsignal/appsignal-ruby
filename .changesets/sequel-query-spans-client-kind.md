---
bump: patch
type: fix
---

Mark Sequel query spans as CLIENT kind in collector mode. The sequel-rails gem
emits its queries as `sql.sequel` ActiveSupport::Notifications events, which are
recorded through the generic notifications integration rather than the dedicated
Sequel hook. That path only tagged `sql.active_record` as an outgoing datastore
call, so Sequel queries were exported with the default span kind. They now carry
CLIENT kind, matching ActiveRecord and the dedicated Sequel hook.
