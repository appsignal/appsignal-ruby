---
bump: minor
type: add
---

Add a Faraday integration. AppSignal now automatically instruments Faraday requests, recording a `request.faraday` event without you having to add Faraday's instrumentation middleware yourself.

The integration is enabled by default and can be turned off with the `instrument_faraday` configuration option (`APPSIGNAL_INSTRUMENT_FARADAY` environment variable).
