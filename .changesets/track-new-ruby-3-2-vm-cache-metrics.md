---
bump: "patch"
type: "change"
---

Track new Ruby 3.2 VM cache metrics. In Ruby 3.2 the `class_serial` and `global_constant_state` metrics are no longer reported for the "Ruby (VM) metrics" magic dashboard, because Ruby 3.2 removed these metrics. Instead we will now report the new `constant_cache_invalidations` and `constant_cache_misses` metrics reported by Ruby 3.2.
