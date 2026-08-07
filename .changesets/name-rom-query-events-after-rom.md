---
bump: patch
type: change
---

Name ROM query events after ROM, rather than after the database they ran
against.

A query made through ROM was reported as `query.postgres`, or `query.sqlite`,
or whatever else the application's database was. The part after the dot is what
AppSignal groups events by, so an application's queries were split into a group
per database engine, and the same application reported one group in production
and another one in its test suite. Those queries are now all reported as
`query.rom`.

Events that dry-monitor reports and AppSignal has no formatter for are now named
after their event id followed by `.dry`, so an event reported as `foo` becomes
`foo.dry`. They had no group at all before.

If you have a dashboard, trigger or saved filter that names one of these events,
point it at the new name.
