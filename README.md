appsignal
=================


## Pull requests / issues

New features should be made in an issue or pullrequest. Title format is as follows:


    name [request_count]

example

    tagging [2]

## Postprocessing middleware
Appsignal logs Rails
[ActiveSupport::Notification](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html)-events
to appsignal.com over SSL. These events contain basic metadata such as a name
and timestamps, and additional 'payload' log data. Appsignal uses a postprocessing
middleware stack to clean up events before they get sent to appsignal.com. You
can add your own middleware to this stack in `config/environment/my_env.rb`.

### Examples

#### Minimal template
```ruby
class MiddlewareTemplate
  def call(event)
    # modify the event in place
    yield # pass control to the next middleware
    # modify the event some more
  end
end

Appsignal.postprocessing_middleware.add MiddlewareTemplate
```

#### Remove boring payloads
```ruby
class RemoveBoringPayload
  def call(event)
    event.payload.clear unless event.name == 'interesting'
    yield
  end
end
```
