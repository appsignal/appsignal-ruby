---
bump: patch
type: fix
---

Fix event formatters that register or unregister themselves. Calling
`unregister` on the formatter itself, as in `MyFormatter.unregister("my.event")`,
did nothing at all. The formatter stayed registered, and no error was raised and
nothing was logged to say so. Calling `register` on the formatter itself stored
it where AppSignal never looked for it, so it was never used to format an event.

Registering and unregistering through `Appsignal::EventFormatter` itself, as in
`Appsignal::EventFormatter.unregister("my.event", MyFormatter)`, was not
affected and keeps working the same way.
