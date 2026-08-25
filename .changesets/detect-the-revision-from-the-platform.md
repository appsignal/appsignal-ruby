---
bump: patch
type: add
---

Detect the revision that is being deployed from the environment variables set by Heroku, Render, Kamal and Scalingo: `HEROKU_SLUG_COMMIT`, `RENDER_GIT_COMMIT`, `KAMAL_VERSION` and `CONTAINER_VERSION`. Applications deployed on those platforms now report their revision without setting the `revision` configuration option.

This affects collector mode, where deploys were reported as `unknown` when the revision was not configured.
