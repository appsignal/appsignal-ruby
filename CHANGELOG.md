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
