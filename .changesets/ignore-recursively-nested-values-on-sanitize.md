---
bump: "patch"
type: "change"
---

When sanitizing an array or hash, ignore recursively nested values. This fixes a SystemStackError issue when sanitising arrays and hashes.
