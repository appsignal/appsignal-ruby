---
bump: patch
type: add
---

Report the `grape` gem version in the environment metadata. Grape is a supported integration (loaded via `Appsignal.load(:grape)`), but it was missing from the list of supported gems used for environment reporting, so Grape applications did not appear in gem-version metadata. Adding it lets AppSignal track Grape adoption and version usage alongside the other supported frameworks.
