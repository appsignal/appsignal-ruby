---
bump: "patch"
type: "change"
---

Reduce our dependency on YAML during installation. Instead of a YAML file with details about the extension download location, use a pure Ruby file. This is a partial fix for the installation issue involving psych version 5.
