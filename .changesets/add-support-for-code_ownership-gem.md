---
bump: patch
type: add
---

Add support for the [CodeOwnership](https://github.com/rubyatscale/code_ownership) gem, which allows engineering teams to declare ownership of specific parts of a codebase.

When an error is reported, the AppSignal gem will tag the transaction with the owner of the file that caused the error.

This feature is enabled by default. To disable it, set the [`instrument_code_ownership` configuration option](https://docs.appsignal.com/ruby/configuration/options.html#option-instrument_code_ownership) to `false`.
