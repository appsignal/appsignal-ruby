---
bump: "patch"
type: "fix"
---

Revert Rack middleware changes (see [changelog](https://github.com/appsignal/appsignal-ruby/blob/main/CHANGELOG.md#360)) to fix issues relating to Unicorn broken pipe errors and multiple requests merging into a single sample.
