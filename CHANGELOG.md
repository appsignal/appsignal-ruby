# 0.9.0
* Add option to override Capistrano revision
* Expanded deploy message in Capistrano
* Random first sleep in background thread
* Refactor of usage of Thread.local
* Net::HTTP instrumentation
* Capistrano 3 support

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
