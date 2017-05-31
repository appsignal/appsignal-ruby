# AppSignal Ruby agent

AppSignal solves all your Ruby monitoring needs in a single tool. You and your
team can focus on writing code and we'll provide the alerts if your app has any
issues.

- [AppSignal.com website][appsignal]
- [Documentation][docs]
- [Support][contact]

[![Build Status](https://travis-ci.org/appsignal/appsignal-ruby.png?branch=master)](https://travis-ci.org/appsignal/appsignal-ruby)
[![Gem Version](https://badge.fury.io/rb/appsignal.svg)](http://badge.fury.io/rb/appsignal)
[![Code Climate](https://codeclimate.com/github/appsignal/appsignal.png)](https://codeclimate.com/github/appsignal/appsignal)

## Description

The AppSignal gem collects exceptions and performance data from your Ruby
applications and sends it to [AppSignal][appsignal] for analysis. Get alerted
when an error occurs or an endpoint is responding very slowly.

AppSignal aims to provide a one stop solution to all your monitoring needs.
Track metrics from your servers with our [Host metrics][host-metrics] and graph
everything else with our [Custom metrics][custom-metrics] feature.

## Usage

First make sure you've installed AppSignal in your application by following the
steps in [Installation](#installation).

AppSignal will automatically monitor requests, report any exceptions that are
thrown and any performance issues that might have occurred.

You can also add extra information to requests by adding custom instrumentation
and by adding tags.

### Track any error

Catch any error and report it to AppSignal, even if it doesn't crash a
request.

```ruby
begin
  config = File.read("config.yml")
rescue => e
  Appsignal.set_error(e)
  # Load alternative config
  config = { :name => ENV["NAME"] }
end
```

Read more about [Exception handling][exception-handling] in our documentation.

### Tagging

Need more information with errors and performance issues? Add tags to your
requests to identify common factors for problems.

```ruby
Appsignal.tag_request(
  user: current_user.id,
  locale: I18n.locale
)
```

Read more about [Tagging][tagging] in our documentation.

### Custom instrumentation

If you need more fine-grained instrumentation you can add custom
instrumentation anywhere in your code.

```ruby
# Simple instrumentation
Appsignal.instrument("array_to_hash.expensive_logic", "Complex calculations") do
  Hash[["a", 1], ["b", 2], ["c", 3]]
end

# Add the query that you're monitoring
sql = "SELECT * FROM posts ORDER BY created_at DESC LIMIT 1"
Appsignal.instrument("fetch.custom_database", "Fetch latest post", sql) do
  # ...
end

# Nested instrumentation calls are also supported!
Appsignal.instrument("fetch.custom_database", "Fetch current user") do
  # ...

  Appsignal.instrument("write.custom_database", "Write user update") do
    # ...
  end
end
```

Read more about [custom instrumentation][custom-instrumentation] in our
documentation.

## Installation

First, [sign up][appsignal-sign-up] for an AppSignal account and add the
`appsignal` gem to your `Gemfile`. Then, run `bundle install`.

```ruby
# Gemfile
gem "appsignal"
```

Afterward, you can use the `appsignal install` command to install AppSignal
into your application by using the "Push API key". This will guide you through
our installation wizard.

```sh
appsignal install [push api key]
```

Depending on what framework or gems you use some manual integration is
required. Follow the steps in the wizard or consult our [integrations] page for
help.

If you're stuck feel free to [contact us][contact]!

## Supported frameworks and gems

AppSignal automatically supports a collection of Ruby frameworks and gems,
including but not limited to:

- Ruby on Rails
- Rack
- Sinatra
- Padrino
- Grape
- Webmachine
- Capistrano
- Sidekiq
- Delayed Job
- Resque
- Rake

AppSignal instrumentation doesn't depend on automatic integrations. It's easy
to set up [custom instrumentation][custom-instrumentation] to add keep track of
anything.

For more detailed information and examples please visit our
[integrations] page.

### Front-end monitoring (Beta)

We have a [Front-end monitoring program][front-end-monitoring] running in Beta
currently. Be sure to check it out!

## Supported systems

Currently the AppSignal agent works on most Unix-like operating systems, such
as most Linux distributions and macOS, excluding FreeBSD and Windows.

For more detailed information please visit our [Supported
systems][supported-systems] page.

## Development & Testing

### Installation

Make sure you have Bundler installed and then use the Rake install task to
install all possible dependencies.

```bash
# Install Bundler
gem install bundler
# Install the AppSignal extension and _all_ gems we support.
bundle exec rake install
# Only install the AppSignal extension.
bundle exec rake extension:install
```

### Testing

```bash
bundle exec rspec
# Or with one file
bundle exec rspec spec/lib/appsignal_spec.rb
```

Note that some specs depend on certain other gems to run and if they are not
loaded RSpec will not run them. See also [Testing with other
gems](#testing-with-other-gems).

#### Testing with other gems

AppSignal runs in many different configurations. To replicate these
configurations you need to run the spec suite with a specific Gemfile.

```
BUNDLE_GEMFILE=gemfiles/capistrano2.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/capistrano3.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/grape.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/no_dependencies.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/padrino.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-3.2.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-4.0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-4.1.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-4.2.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-5.0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/resque.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/sequel-435.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/sequel.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/sinatra.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/webmachine.gemfile bundle exec rspec
```

If you have either [RVM][rvm] or [rbenv][rbenv] installed you can also use
`rake generate_bundle_and_spec_all` to generate a script that runs specs for
all Ruby versions and gem combinations we support.

We run the suite against all of the Gemfiles mentioned above and on
a number of different Ruby versions.

### Versioning

This gem uses [Semantic Versioning][semver].

The `master` branch corresponds to the current stable release of the gem.

The `develop` branch is used for development of features that will end up in
the next minor release.

Open a Pull Request on the `master` branch if you're fixing a bug. For new new
features, open a Pull Request on the `develop` branch.

Every stable and unstable release is tagged in git with a version tag.

## Contributing

Thinking of contributing to our gem? Awesome! 🚀

Please follow our [Contributing guide][contributing-guide] in our
documentation.

Also, we would be very happy to send you Stroopwafles. Have look at everyone
we send a package to so far on our [Stroopwafles page][waffles-page].

## Support

[Contact us][contact] and speak directly with the engineers working on
AppSignal. They will help you get set up, tweak your code and make sure you get
the most out of using AppSignal.

[appsignal]: https://appsignal.com
[appsignal-sign-up]: https://appsignal.com/users/sign_up
[contact]: mailto:support@appsignal.com
[waffles-page]: https://appsignal.com/waffles
[docs]: http://docs.appsignal.com
[contributing-guide]: http://docs.appsignal.com/appsignal/contributing.html
[supported-systems]: http://docs.appsignal.com/support/operating-systems.html
[integrations]: http://docs.appsignal.com/ruby/integrations/index.html
[custom-instrumentation]: http://docs.appsignal.com/ruby/instrumentation/
[front-end-monitoring]: http://docs.appsignal.com/front-end/error-handling.html
[exception-handling]: http://docs.appsignal.com/ruby/instrumentation/exception-handling.html
[tagging]: http://docs.appsignal.com/ruby/instrumentation/tagging.html
[host-metrics]: http://docs.appsignal.com/metrics/host.html
[custom-metrics]: http://docs.appsignal.com/metrics/custom.html

[semver]: http://semver.org/
[rvm]: http://rvm.io/
[rbenv]: https://github.com/rbenv/rbenv
