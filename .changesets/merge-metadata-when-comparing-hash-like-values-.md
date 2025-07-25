---
bump: patch
type: fix
---

When using the transaction helpers to set metadata like `add_params`, `add_sesion_data`, etc.), we will now merge Hash-like values, value types that are subclasses of the Ruby Hash class.
Now, if a `ActiveSupport::HashWithIndifferentAccess` or `Sinatra::IndifferentHash` value is given, it will be merged with the existing Hash-like value instead of replacing the original value.
