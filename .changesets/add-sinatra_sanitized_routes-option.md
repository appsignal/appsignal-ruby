---
bump: "patch"
type: "add"
---

Add sinatra_sanitized_routes option to store sanitized routes instead of the real request path in the Transaction's metadata. This can be useful if there's PII or other sensitive data in the app's request paths. Set `sinatra_sanitized_routes` to `true` in the AppSignal config to enable this behavior and store the route definition rather than the real request path as metadata. We also recommend changing the `request_headers` config option to not include any headers that also include the real request path.
