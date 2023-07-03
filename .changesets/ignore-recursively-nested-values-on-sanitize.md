---
bump: "patch"
type: "change"
---

When sanitizing an array or hash, replace recursively nested values with a placeholder string. This fixes a SystemStackError issue when sanitising arrays and hashes.
