---
bump: patch
type: add
---

Add the `Appsignal.config_error` and `Appsignal.config_error?` methods. This method contains any error that may have occurred while loading the `config/appsignal.rb` file. If it is `nil` no error occurred or `Appsignal.start` hasn't been called yet. The `Appsignal.config_error?` method is an alias for syntax sugar.
