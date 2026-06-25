---
bump: minor
type: add
---

Add a Faraday integration. AppSignal now automatically instruments Faraday requests, recording a `request.faraday` event without you having to add Faraday's instrumentation middleware yourself. In collector mode, outgoing Faraday requests carry W3C trace context so the called service joins the same distributed trace.

The integration is enabled by default and can be turned off with the `instrument_faraday` configuration option (`APPSIGNAL_INSTRUMENT_FARADAY` environment variable).
