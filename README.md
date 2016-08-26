AppSignal agent
=================

This gem collects error and performance data from your Rails
applications and sends it to [AppSignal](https://appsignal.com)

[![Build Status](https://travis-ci.org/appsignal/appsignal-ruby.png?branch=master)](https://travis-ci.org/appsignal/appsignal-ruby)
[![Gem Version](https://badge.fury.io/rb/appsignal.svg)](http://badge.fury.io/rb/appsignal)
[![Code Climate](https://codeclimate.com/github/appsignal/appsignal.png)](https://codeclimate.com/github/appsignal/appsignal)

## Development

Make sure you have Bundler installed and then use the Rake install task to
install all other dependencies.

```
gem install bundler
rake install
```

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

If you have either Rvm or Rbenv installed you can also use
`rake generate_bundle_and_spec_all` to generate a script that runs specs for
all Ruby versions and gem combinations we support.

On Travis we run the suite against all of the Gemfiles mentioned above and on
a number of different Ruby versions.

## Branches and versions

The `master` branch corresponds to the current release of the gem. The
`develop` branch is used for development of features that will end up in
the next minor release. If you fix a bug open a pull request on `master`, if
it's a new feature on `develop`.
