---
bump: patch
type: remove
---

Remove the `app_path` writer in the `Appsignal.configure` helper. This was deprecated in version 3.x. It is removed now in the next major version.

Use the `root_path` keyword argument in the `Appsignal.configure` helper (`Appsignal.configure(:root_path => "...")`) to change the AppSignal root path if necessary.
