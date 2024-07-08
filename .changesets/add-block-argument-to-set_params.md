---
bump: patch
type: add
---

Add a block argument to the `Appsignal.set_params` and `Appsignal::Transaction#set_params` helpers. When `set_params` is called with a block argument, the block is executed when the parameters are stored on the Transaction. This block is only called when the Transaction is sampled. Use this block argument to avoid having to parse parameters for every transaction, even when it's not sampled.

```ruby
Appsignal.set_params do
  # Some slow code to parse parameters
  JSON.parse('{"param1": "value1"}')
end
```
