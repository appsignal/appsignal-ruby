---
bump: "minor"
type: "add"
---

Add instrumentation for all Rack responses, including streaming responses. New `response_body_each.rack`, `response_body_call.rack` and `response_body_to_ary.rack` events will be shown in the event timeline. This will show how long it takes to complete responses, depending on the response implementation.

This Sinatra route with a streaming response will be better instrumented, for example:

```ruby
get "/stream" do
  stream do |out|
    sleep 1
    out << "1"
    sleep 1
    out << "2"
    sleep 1
    out << "3"
  end
end
```
