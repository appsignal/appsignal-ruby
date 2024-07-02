---
bump: "minor"
type: "add"
---

Add instrumentation to Rack responses, including streaming responses. New `process_response_body.rack` and `close_response_body.rack` events will be shown in the event timeline. These events show how long it takes to complete responses, depending on the response implementation, and when the response is closed.

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
