appsignal
=================


## Pull requests / issues

New features should be made in an issue or pullrequest. Title format is as follows:


    name [request_count]

example

    tagging [2]

## Event payload sanitizer
Appsignal logs Rails
[ActiveSupport::Notification](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html)-events
to appsignal.com over SSL. These events contain basic metadata such as a name
and timestamps, and additional 'payload' log data. By default,
appsignal will transmit all payload data. If you want to restrict the amount of
payload data that gets sent to <https://appsignal.com>, you can define your own
event payload sanitizer in `config/environment/my_env.rb`. The
`event_payload_sanitizer` needs to be a callable object that returns a
JSON-serializable hash.

### Examples

#### Pass through the entire payload unmodified (default)
```ruby
Appsignal.event_payload_sanitizer = proc { |event| event.payload }
```

#### Delete the entire event payload
```ruby
Appsignal.event_payload_sanitizer = proc { {} }
```

#### Conditional modification of the payload
```ruby
Appsignal.event_payload_sanitizer = proc do |event|
  if event.name == 'interesting'
    event.payload
  else
    {}
  end
end
```
