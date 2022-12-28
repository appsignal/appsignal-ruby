---
bump: "patch"
type: "fix"
---

Attempt to load C extension from lib/ directory. Fixes an issue where JRuby would fail to load
the extension from the ext/ directory, as the directory is cleaned after installation when using
RubyGems 3.4.0.
