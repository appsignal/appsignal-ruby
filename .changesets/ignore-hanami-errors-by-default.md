---
bump: patch
type: change
---

Ignore these Hanami errors by default:

- Hanami::Router::NotAllowedError (for example: sending a GET request to POST endpoint)
- Hanami::Router::NotFoundError

They are usually errors you don't want to be notified about, so we ignore them by default now.

Customize the `ignore_errors` config option to continue receiving these errors.
