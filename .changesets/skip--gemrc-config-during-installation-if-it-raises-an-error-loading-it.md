---
bump: "patch"
type: "fix"
---

Skip the `.gemrc` config during installation if it raises an error loading it. This can be caused when the psych gem version 5 is installed on Ruby < 3.2. Use the `HTTP_PROXY` environment variable instead to configure the HTTP proxy that should be used during installation.
