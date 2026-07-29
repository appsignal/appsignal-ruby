---
bump: patch
type: change
---

In collector mode, each AppSignal integration now records its spans under its own OpenTelemetry instrumentation scope. The scope is named after the integration, for example `appsignal-ruby/sidekiq` or `appsignal-ruby/net_http`. The Rails components that are bridged through `ActiveSupport::Notifications` are named after the component, for example `appsignal-ruby/active_record` and `appsignal-ruby/action_view`. This makes it possible to group spans by the integration that produced them. Custom instrumentation keeps the default `appsignal-ruby` scope, and so does anything else without a more specific scope.
