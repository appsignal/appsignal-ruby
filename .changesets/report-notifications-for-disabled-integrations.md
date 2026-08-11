---
bump: patch
type: change
---

Report Active Job's and Faraday's own instrumentation events again when AppSignal's instrumentation for those libraries is turned off. Since version 4.9.0, an application that set `instrument_active_job` or `instrument_faraday` to `false` got no event for that work at all.
