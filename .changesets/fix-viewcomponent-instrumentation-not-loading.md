---
bump: patch
type: fix
---

Fix an issue where, depending on the relative order of the `appsignal` and `view_component` dependencies in the Gemfile, the ViewComponent instrumentation would not load.
