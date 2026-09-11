---
bump: patch
type: fix
---

Report request headers for Webmachine applications. Webmachine names a request header in lowercase and with dashes, such as `accept`, while the `request_headers` configuration option lists the Rack names for the same headers, such as `HTTP_ACCEPT`. Nothing matched, so a Webmachine application reported an empty request environment.

This affected both the agent and collector mode.
