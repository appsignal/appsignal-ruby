---
bump: minor
type: add
---

Add config options to turn individual integrations off. Set
`instrument_sidekiq`, `instrument_shoryuken`, `instrument_que`,
`instrument_resque`, `instrument_delayed_job`, `instrument_active_job`,
`instrument_excon` or `instrument_mongo` to `false` to disable that
integration entirely. This turns off both the instrumentation of the jobs or
requests and the enqueue instrumentation for that integration. They all
default to `true`. Each can also be set through its environment variable, such
as `APPSIGNAL_INSTRUMENT_SIDEKIQ`.
