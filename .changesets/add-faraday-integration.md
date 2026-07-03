---
bump: minor
type: add
---

Improve Faraday support. AppSignal now instruments Faraday requests automatically, without double-instrumenting the underlying HTTP client. Turn it off with the `instrument_faraday` option.
