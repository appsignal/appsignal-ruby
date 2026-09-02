---
bump: patch
type: add
---

Report the host, the port and the HTTP version of an incoming web request in collector mode. These are sent as the `server.address`, `server.port` and `network.protocol.version` OpenTelemetry attributes. The host is read from the `Forwarded` and `X-Forwarded-Host` headers when a proxy sets them, so it is the host the client used rather than the one the proxy connected to.
