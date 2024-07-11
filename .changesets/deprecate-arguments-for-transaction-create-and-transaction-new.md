---
bump: patch
type: deprecate
---

Deprecate the 'ID', 'request', and 'options' arguments for the `Transaction.create` and `Transaction.new` methods. To add metadata to the transaction, use the `Appsignal.set_*` helpers. Read our [sample data guide](https://docs.appsignal.com/guides/custom-data/sample-data.html) for more information on how to set metadata on transactions.

```ruby
# Before
Appsignal::Transaction.create(
  SecureRandom.uuid,
  "my_namespace",
  Appsignal::Transaction::GenericRequest.new(env) # env is a request env Hash
)

# After
Appsignal::Transaction.create("my_namespace")
```
