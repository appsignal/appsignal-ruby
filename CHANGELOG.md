# 0.11.12
* Sanitizer will no longer inspect unknown objects, since implementations of inspect sometimes trigger unexpected behavior.

# 0.11.11
* Reliably get errors in production for Sinatra

# 0.11.10
* Fix for binding bug in exceptions in Resque
* Handle invalidly encoded characters in payload

# 0.11.9
* Fix for infinite attempts to transmit if there is no valid api key

# 0.11.8
* Add frontend error catcher
* Add background job metadata (queue, priority etc.) to transaction overview
* Add APPSIGNAL_APP_ENV variable to Rails config, so you can override the environment
* Handle http queue times in microseconds too
* Use less memory when retrying transmissions and don't retry if there's
  a queue on shutdown

# 0.11.7
* Add option to override Job name in Delayed Job

# 0.11.6
* Use `APPSIGNAL_APP_NAME` and `APPSIGNAL_ACTIVE` env vars in config
* Better Sinatra support: Use route as action and set session data for Sinatra

# 0.11.5
* Add Sequel gem support (https://github.com/jeremyevans/sequel)

# 0.11.4
* Make `without_instrumentation` thread safe

# 0.11.3
* Support Ruby 1.9 and up instead of 1.9.3 and up

# 0.11.2
* If APP_REVISION environment variable is set, send it with the log entry.

# 0.11.1
* Allow a custom request_class and params_method on  Rack instrumentation
* Loop through env methods instead of env
* Add HTTP_CLIENT_IP to env methods

# 0.11.0
* Improved inter process communication
* Retry sending data when the push api is not reachable
* Our own event handling to allow for more flexibility and reliability
  when using a threaded environment
* Resque officially supported!

# 0.10.6
* Add config option to skip session data

# 0.10.5
* Don't shutdown in `at_exit`
* Debug log about missing name in config

# 0.10.4
* Add REQUEST_URI and PATH_INFO to env params whitelist

# 0.10.3
* Shut down all operations when agent is not active
* Separately rescue OpenSSL::SSL::SSLError

# 0.10.2
* Bugfix in event payload sanitization

# 0.10.1
* Bugfix in event payload sanitization

# 0.10.0
* Remove ActiveSupport dependency
* Use vendored notifications if ActiveSupport is not present
* Update bundled CA certificates
* Fix issue where backtrace can be nil
* Use Appsignal.monitor_transaction to instrument and log errors for
  custom actions
* Add option to ignore a specific action

# 0.9.6
* Convert to primitives before sending through pipe

# 0.9.5
Yanked

# 0.9.4
* Log Rails and Sinatra version
* Resubscribe to notifications after fork

# 0.9.3
* Log if appsignal is not active for an environment

# 0.9.2
* Log Ruby version and platform on startup
* Log reason of shutting down agent

# 0.9.1
* Some debug logging tweaks

# 0.9.0
* Add option to override Capistrano revision
* Expanded deploy message in Capistrano
* Refactor of usage of Thread.local
* Net::HTTP instrumentation
* Capistrano 3 support

# 0.8.15
* Exception logging in agent thread

# 0.8.14
* Few tweaks in logging
* Clarify Appsignal::Transaction.complete! code

# 0.8.13
* Random sleep time before first transmission of queue

# 0.8.12
* Workaround for frozen string in Notification events
* Require ActiveSupport::Notifications to be sure it's available

# 0.8.11
* Skip enqueue, send_exception and add_exception if not active

# 0.8.10
* Bugfix: Don't pause agent when it's not active

# 0.8.9
Yanked

# 0.8.8
* Explicitely require securerandom

# 0.8.7
* Dup process action event to avoid threading issue
* Rescue failing inspects in param sanitizer
* Add option to pause instrumentation

# 0.8.6
* Resque support (beta)
* Support tags in Appsignal.send_exception
* Alias tag_request to tag_job, for background jobs
* Skip sanitization of env if env is nil
* Small bugfix in forking logic
* Don't send params if send_params is off in config
* Remove --repository option in CLI
* Name option in appsignal notify_of_deploy CLI
* Don't call to_hash on ENV
* Get error message in CLI when config is not active

# 0.8.5
* Don't require revision in CLI notify_of_deploy

# 0.8.4
* Skip session sanitize if not a http request
* Use appsignal_config in Capistrano as initial config

# 0.8.3
* Restart thread when we've been forked
* Only notify of deploy when active in capistrano
* Make sure env is a string in config

# 0.8.2
* Bugfix in Delayed Job integration
* appsignal prefix when logging to stdout
* Log to stdout on Shelly Cloud

# 0.8.1
* Fix in monitoring of queue times

# 0.8.0
* Support for background processors (Delayed Job and Sidekiq)

# 0.7.1
* Better support for forking webservers

# 0.7.0
* Mayor refactor and cleanup
* New easier onboarding process
* Support for Rack apps, including experimental Sinatra integration
* Monitor HTTP queue times
* Always log to stdout on Heroku

# 0.6.7
* Send HTTP_X_FORWARDED_FOR env var

# 0.6.6
* Add Appsignal.add_exception

# 0.6.5
* Fix bug where fast requests are tracked with wrong action

# 0.6.4
* More comprehensive debug logging

# 0.6.3
* Use a mutex around access to the aggregator
* Bugfix for accessing connection config in Rails 3.0
* Add Appsignal.tag_request
* Only warn if there are duplicate push keys

# 0.6.2
* Bugfix in backtrace cleaner usage for Rails 4

# 0.6.1
* Bugfix in Capistrano integration

# 0.6.0
* Support for Rails 4
* Data that's posted to AppSignal is now gzipped
* Add Appsignal.send_exception and Appsignal.listen_for_exception
* We now us the Rails backtrace cleaner

# 0.5.5
* Fix minor bug

# 0.5.4
* Debug option in config to get detailed logging

# 0.5.3
* Fix minor bug

# 0.5.2
* General improvements to the Rails generator
* Log to STDOUT if writing to log/appsignal.log is not possible (Heroku)
* Handle the last transactions before the rails process shuts down
* Require 'erb' to enable dynamic config
