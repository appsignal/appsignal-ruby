---
bump: patch
type: change
---

Rename the `path` and `method` transaction metadata to `request_path` and `request_method` to make it more clear what context this metadata is from. The `path` and `method` metadata will continue to be reported until the next major/minor version.
