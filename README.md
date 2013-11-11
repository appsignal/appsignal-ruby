AppSignal agent
=================

This gem collects error and performance data from your Rails
applications and sends it to [AppSignal](https://appsignal.com)

[![Build Status](https://travis-ci.org/appsignal/appsignal.png?branch=develop)](https://travis-ci.org/appsignal/appsignal)
[![Code Climate](https://codeclimate.com/github/appsignal/appsignal.png)](https://codeclimate.com/github/appsignal/appsignal)

## Pull requests / issues

New features should be made in an issue or pullrequest. Title format is as follows:

    name [request_count]

example

    tagging [2]

## Postprocessing middleware

Appsignal sends Rails
[ActiveSupport::Notification](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html)-events
to AppSignal over SSL. These events contain basic metadata such as a name
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

## Development

Run rake bundle or, or run bundle install for all Gemfiles:

```
bundle --gemfile gemfiles/no_dependencies.gemfile
bundle --gemfile gemfiles/rails-3.0.gemfile
bundle --gemfile gemfiles/rails-3.1.gemfile
bundle --gemfile gemfiles/rails-3.2.gemfile
bundle --gemfile gemfiles/rails-4.0.gemfile
bundle --gemfile gemfiles/sinatra.gemfile
```

To run the spec suite with a specific Gemfile:

```
BUNDLE_GEMFILE=gemfiles/no_dependencies.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-3.0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-3.1.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-3.2.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-4.0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/sinatra.gemfile bundle exec rspec
```

Or run `rake spec` to run specs for all Gemfiles. Travis will run specs for these Gemfiles as well.
