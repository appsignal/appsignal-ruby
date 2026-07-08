---
bump: minor
type: add
---

Improve Faraday support. AppSignal now instruments Faraday requests automatically, without double-instrumenting the underlying HTTP client, and, in collector mode, propagates trace context to the called service so it joins the same distributed trace. Turn it off with the `instrument_faraday` option.
