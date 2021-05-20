---
bump: "patch"
---

Skip empty HTTP proxy config. When any of the HTTP proxy config returns an
empty string, skip this config. This fixes installation issues where an empty
String is used as a HTTP proxy, causing a RuntimeError upon installation.
