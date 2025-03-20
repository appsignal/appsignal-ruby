---
bump: patch
type: add
---

Add the `enable_at_exit_hook` option to configure if `Appsignal.stop` is called when the Ruby application exits. Calling `Appsignal.stop` will stop the application for a moment to flush all the data to our agent before shutting down.

This behavior is enabled by default, but can be disabled by setting `enable_at_exit_hook` to `false` in your AppSignal configuration. We recommend leaving this on, especially if the `enable_at_exit_reporter` option is turned on, which reports errors that crash the application.
