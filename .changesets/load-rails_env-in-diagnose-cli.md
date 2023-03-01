---
bump: "patch"
type: "change"
---

Configure AppSignal with the RACK_ENV or RAILS_ENV environment variable in diagnose CLI, if present. Makes it easier to run the diagnose CLI in production, without having to always specify the environment with the `--environment` CLI option.
