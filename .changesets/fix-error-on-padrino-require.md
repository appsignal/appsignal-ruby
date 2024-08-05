---
bump: patch
type: fix
---

Fix an error on the Padrino require in the installer CLI. The latest Padrino version will crash the installer on load. Ignore the error when it fails to load.
