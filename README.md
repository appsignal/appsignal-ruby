AppSignal agent
=================

This gem collects error and performance data from your Rails
applications and sends it to [AppSignal](https://appsignal.com)

[![Build Status](https://travis-ci.org/appsignal/appsignal.png?branch=master)](https://travis-ci.org/appsignal/appsignal-ruby)
[![Gem Version](https://badge.fury.io/rb/appsignal.svg)](http://badge.fury.io/rb/appsignal)
[![Code Climate](https://codeclimate.com/github/appsignal/appsignal.png)](https://codeclimate.com/github/appsignal/appsignal)

## Development

Run `rake install`, then run the spec suite with a specific Gemfile:

```
BUNDLE_GEMFILE=gemfiles/capistrano2.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/capistrano3.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/no_dependencies.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/padrino.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-3.0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-3.1.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-3.2.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-4.0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-4.1.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails-4.2.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/sequel.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/sinatra.gemfile bundle exec rspec
```

Or run `rake generate_bundle_and_spec_all` to generate a script that runs specs for all
Ruby versions and gem combinations we support.
You need Rvm or Rbenv to do this. Travis will run specs for these combinations as well.

## Branches and versions

The `master` branch corresponds to the current release of the gem. The
`develop` branch is used for development of features that will end up in
the next minor release. If you fix a bug open a pull request on `master`, if
it's a new feature on `develop`.
