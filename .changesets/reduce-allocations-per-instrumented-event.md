---
bump: patch
type: change
integrations: ruby
---

Reduce the objects allocated for every recorded ActiveSupport::Notifications event and every Action View and ViewComponent render. The instrumentation scope and the template or component path relative to the application root are now computed once per event name or path.
