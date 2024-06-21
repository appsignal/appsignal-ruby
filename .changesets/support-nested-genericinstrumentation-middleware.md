---
bump: patch
type: change
---

Improve support for instrumentation of nested pure Rack and Sinatra apps. It will now report more of the request's duration and events. This also improves support for apps that have multiple Rack GenericInstrumentation or SinatraInstrumentation middlewares.
