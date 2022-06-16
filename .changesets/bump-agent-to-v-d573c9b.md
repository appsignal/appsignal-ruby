---
bump: "patch"
type: "change"
---

Bump agent to v-d573c9b

- Display unsupported OpenTelemetry spans in limited form.
- Clean up payload storage before sending. Should fix issues with locally queued payloads blocking data from being sent.
- Add `appsignal_create_opentelemetry_span` function to create spans for further modification, rather than only import them.
