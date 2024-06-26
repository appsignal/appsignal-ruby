---
bump: patch
type: deprecate
---

Deprecate `Appsignal::Grape::Middleware` constant in favor of `Appsignal::Rack::GrapeMiddleware` constant.

To fix this deprecation warning, update the usage of `Appsignal::Grape::Middleware` like this:

```ruby
# Grape only apps
insert_before Grape::Middleware::Error, Appsignal::Rack::GrapeMiddleware
# or
use Appsignal::Rack::GrapeMiddleware

# Grape on Rails app
use Appsignal::Rack::GrapeMiddleware
```
