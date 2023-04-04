---
bump: "patch"
type: "add"
---

Add Rails [error reporter](https://guides.rubyonrails.org/error_reporting.html) support. Errors reported using `Rails.error.handle` are tracked as separate errors in AppSignal. We rely on our other Rails instrumentation to report the errors reported with `Rails.error.record`.

The error is reported under the same controller/job name, on a best effort basis. It may not be 100% accurate. If `Rails.error.handle` is called within a Rails controller or Active Job job, it will copy the AppSignal transaction namespace, action name and tags from the current transaction to the transaction for the `Rails.error.handle` reported error. If you call `Appsignal.set_namespace`, `Appsignal.set_action` or `Appsignal.tag_request` after `Rails.error.handle`, those changes will not be reflected up in the already reported error.

It is also possible to customize the AppSignal namespace and action name for the reported error using the `appsignal` context:

```ruby
Rails.error.handle(:context => { :appsignal => { :namespace => "context", :action => "ContextAction" } }) do
  raise "Test"
end
```

All other key-values are reported as tags:

```ruby
Rails.error.handle(:context => { :tag_key => "tag value" }) do
  raise "Test"
end
```

Integration with the Rails error reporter is enabled by default. Disable this feature by setting the `enable_rails_error_reporter` config option to `false`.
