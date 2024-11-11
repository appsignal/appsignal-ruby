---
bump: patch
type: add
---

Add `Appsignal.set_empty_params!` helper method. This helper method can be used to unset parameters on a transaction and to prevent the Appsignal instrumentation from adding parameters to a transaction.

Example usage:

```ruby
class PaymentsController < ApplicationController
  def create
    Appsignal.set_empty_params!

    # Do things with sensitive parameters
  end
end
```

When `Appsignal.add_params` is called afterward, the "empty parameters" state is cleared and any AppSignal instrumentation (if called afterward) will also add parameters again.

```ruby
# Example: Unset parameters when set
Appsignal.add_params("abc" => "def")
# Parameters: { "abc" => "def" }
Appsignal.set_empty_params!
# Parameters: {}

# Example: When AppSignal instrumentation sets parameters:
Appsignal.set_empty_params!
# Parameters: {}
# Example code:
Appsignal::Instrumtation::SomeLibrary.new.add_params("xyz" => "...")
# Parameters: {}

# Example: Set parameters after them being unset previously
Appsignal.set_empty_params!
# Parameters: {}
Appsignal.add_params("abc" => "def")
# Parameters: { "abc" => "def" }
```
