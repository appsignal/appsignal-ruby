---
bump: patch
type: change
---

Use the revision set by Heroku, Render, Kamal or Scalingo when the application also has a `REVISION` file. Since version 4.6.0, a `REVISION` file took precedence over the `HEROKU_SLUG_COMMIT`, `RENDER_GIT_COMMIT`, `KAMAL_VERSION` and `CONTAINER_VERSION` environment variables, so an application that kept a placeholder `REVISION` file in source control reported that placeholder as its revision. The `revision` config option and the `APP_REVISION` environment variable still take precedence over both.

Thanks to @rmm5t for their contribution!
