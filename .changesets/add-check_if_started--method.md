---
bump: patch
type: add
---

Add the `check_if_started!` method. This method will raise an error if the AppSignal Ruby gem failed to start.

Call this method in your CI or on app boot if you wish to verify that AppSignal has started when your application does, and want the application to fail to start if AppSignal hasn't started.

For example, in this Rails initializer:

```
# config/initializers/appsignal.rb

Appsignal.check_if_started!
```
