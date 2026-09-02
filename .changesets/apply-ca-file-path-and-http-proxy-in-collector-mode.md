---
bump: patch
type: fix
---

The `ca_file_path` and `http_proxy` options now apply to the data sent to the collector in collector mode. Before this change they only applied to the data sent by the agent, so a custom certificate authority file or a proxy had no effect in collector mode.
