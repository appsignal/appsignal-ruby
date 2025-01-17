---
bump: patch
type: add
---

Add support for the [Ownership](https://github.com/ankane/ownership) gem, which is used to mark different segments of the application as owned by specific teams.

The AppSignal sample will be tagged with the given owner:

```ruby
class OrdersController < ApplicationController
  owner :logistics
  # Transactions for requests handled by this controller will be tagged
  # in AppSignal with the "owner" tag set to "logistics"
end
```

If several owners are set within the same transaction, the last owner will take precedence. If an error is reported in the transaction, the owner tag will be set to the owner that was set when the error was raised.

Set the [`ownership_set_namespace` configuration option](https://docs.appsignal.com/ruby/configuration/options.html#option-ownership_set_namespace) to `true` to also set the AppSignal sample's namespace to the owner. Note that doing so will cause existing performance and error incidents to be re-created with the new namespace.

Set the [`instrument_ownership` configuration option](https://docs.appsignal.com/ruby/configuration/options.html#option-instrument_ownership) to `false` to disable the integration with the Ownership gem.
