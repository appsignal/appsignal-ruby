AppSignal agent
=================

This gem collects error and performance data from your Rails
applications and sends it to [AppSignal](https://appsignal.com)

[![Build Status](https://travis-ci.org/appsignal/appsignal.png?branch=master)](https://travis-ci.org/appsignal/appsignal)
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


---

Examples
=================

Add performance monitoring to a continuously running multi-threaded rake task for v1.1.6. (The appsignal gem does error monitoring of rake tasks automatically.) Based on work of leehambley.

```ruby
# do_something.rake
namespace :mycrazyproject do
  task do_something: :environment do
    while true
      User.where(active:true).find_in_batches(batch_size:20).with_index do |batch_of_users, batch_ndx|
        # We collect a bunch of new threads, one for each
        # user, eac 
        #
        batch_threads = batch_of_users.collect do |user_outer|
          #
          # We pass the user to the thread, this is good
          # habit for shared variables, in this case
          # it doesn't make much difference
          #
          Thread.new(user_outer) do |u|
            #
            # Do the API call here use `u` (not `user`)
            # to access the user instance
            #
            # We shouldn't need to use an evented HTTP library
            # Ruby threads will pass control when the IO happens
            # control will return to the thread sometime when
            # the scheduler decides, but 99% of the time
            # HTTP and network IO are the best thread optimized
            # thing you can do in Ruby.
            transaction = Appsignal::Transaction.create(SecureRandom.uuid, Appsignal::Transaction::BACKGROUND_JOB, Appsignal::Transaction::GenericRequest.new(:params => {user_data:"hello",user_id:u.id,something_else:u.something_else}))
            transaction.set_action("name.of.background.action.you.want.in.appsignal")
            begin
              ActiveSupport::Notifications.instrument(
                'perform_job.long_running_task',
                :class => 'User',
                :method => 'long_running_task'
              ) do
                  u.long_running_task
                end
              rescue Exception => err
                transaction.set_error(err)
              ensure
                # Complete the transaction
                Appsignal::Transaction.complete_current!
              end

          end
        end
        #
        # Joining threads means waiting for them to finish
        # before moving onto the next batch.
        #
        batch_threads.map(&:join)
      end
      ##########
    end
  end
end
```
