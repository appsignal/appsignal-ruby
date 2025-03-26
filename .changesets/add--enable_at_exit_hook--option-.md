---
bump: patch
type: add
---

Add the `enable_at_exit_hook` option to configure if `Appsignal.stop` is called when the Ruby application exits. Calling `Appsignal.stop` will stop the application for a moment to flush all the data to our agent before shutting down.

This option has three possible values:

- `always`: Always call `Appsignal.stop` when the program exits. On (Docker) containers it's automatically set to this value.
- `never`: Never call `Appsignal.stop` when the program exits. The default value when the program doesn't run on a (Docker) container.
- `on_error`: Call `Appsignal.stop` when the program exits with an error.
