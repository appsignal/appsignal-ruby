---
bump: "patch"
type: "change"
---

Listen to the `APPSIGNAL_HTTP_PROXY` environment variable in the extension installer. When `APPSIGNAL_HTTP_PROXY` is set during `gem instal appsignal` or `bundle install`, it will use the proxy specified in the `APPSIGNAL_HTTP_PROXY` environment variable to download the extension and agent.
