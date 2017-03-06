# 2.1.1
* Fix DNS issue related to musl build.
  Commit 732c877de8faceabe8a977bf80a82a6a89065c4d
* Update benchmark and add load test. PR #248
* Fix configuring instrument redis and sequel from env. PR #257

# 2.1.0
* Add support for musl based libc (Alpine Linux). PR #229
* Implement `Appsignal.is_ignored_error?` and `Appsignal.is_ignored_action?`
  logic in the AppSignal extension. PR #224
* Deprecate `Appsignal.is_ignored_error?`. PR #224
* Deprecate `Appsignal.is_ignored_action?`. PR #224
* Enforce a coding styleguide with RuboCop. PR #226
* Remove unused `Appsignal.agent` attribute. PR #244
* Deprecate unused `Appsignal::AuthCheck` logger argument. PR #245

# 2.0.6
* Fix `Appsignal::Transaction#record_event` method call. PR #240

# 2.0.5
* Improved logging for agent connection issues.
  Commit cdf9d3286d704e22473eb901c839cab4fab45a6f
* Handle nil request/environments in transactions. PR #231

# 2.0.4
* Use consistent log format for both file and STDOUT logs. PR #203
* Fix log path in `appsignal diagnose` for Rails applications. PR #218, #222
* Change default log path to `./log` rather than project root for all non-Rails
  applications. PR #222
* Load the `APPSIGNAL_APP_ENV` environment configuration option consistently
  for all integrations. PR #204
* Support the `--environment` option on the `appsignal diagnose` command. PR
  #214
* Use the real system `/tmp` directory, not a symlink. PR #219
* Run the AppSignal agent in diagnose mode in the `appsignal diagnose` command.
  PR #221
* Test for directory and file ownership and permissions in the
  `appsignal diagnose` command. PR #216
* Test if current user is `root` in the `appsignal diagnose` command. PR #215
* Output last couple of lines from `appsignal.log` on agent connection
  failures.
* Agent will no longer fail to start if no writable log path is found.
  Commit 8920865f6158229a46ed4bd1cc98d99a849884c0, change in agent.
* Internal refactoring of the test suite and the `appsignal install` command.
  PR #200, #205

# 2.0.3
* Fix JavaScript exception catcher throwing an error on finishing a
  transaction. PR #210

# 2.0.2
* Fix Sequel instrumentation overriding existing logic from extensions. PR #209

# 2.0.1
* Fix configuration load order regression for the `APPSIGNAL_PUSH_API_KEY`
  environment variable's activation behavior. PR #208

# 2.0.0
* Add `Appsignal.instrument_sql` convenience methods. PR #136
* Use `Appsignal.instrument` internally instead of ActiveSupport
  instrumentation. PR #142
* Override ActiveSupport instrument instead of subscribing. PR #150
* Remove required dependency on ActiveSupport. Recommended you use
  `Appsignal.instrument` if you don't need `ActiveSupport`. PR #150 #142
* Use have_library to link the AppSignal extension `libappsignal`. PR #148
* Rename `appsignal_extension.h` to `appsignal.h`.
  Commit 9ed7c8d83f622d5a79c5c21d352b3360fd7e8113
* Refactor rescuing of Exception. PR #173
* Use GC::Profiler to track garbage collection time. PR #134
* Detect if AppSignal is running in a container or Heroku. PR #177 #178
* Change configuration load order to load environment settings after
  `appsignal.yml`. PR #178
* Speed up payload generation by letting the extension handle it. PR #175
* Improve `appsignal diagnose` formatting and output more data. PR #187
* Remove outdated `appsignal:diagnose` rake tasks. Use `appsignal diagnose`
  instead. PR #193
* Fix JavaScript exception without names resulting in errors themselves. PR #188
* Support namespaces in Grape routes. PR #189
* Change STDOUT output to always mention "AppSignal", not "Appsignal". PR #192
* `appsignal notify_of_deploy` refactor. `--name` will override any
  other `name` config. `--environment` is only required if it's not set in the
  environment. PR #194
* Allow logging to STDOUT. Available for the Ruby gem and C extension. The
  `appsignal-agent` process will continue log to file. PR #190
* Remove deprecated methods. PR #191
* Send "ruby" implementation name with version number for better identifying
  different language implementations. PR #198
* Send demonstration samples to AppSignal using the `appsignal install`
  command instead of asking the user to start their app. PR #196
* Add `appsignal demo` command to test the AppSignal demonstration samples
  instrumentation manually and not just during the installation. PR #199

# 1.3.6
* Support blocks arguments on method instrumentation. PR #163
* Support `APPSIGNAL_APP_ENV` for Sinatra. PR #164
* Remove Sinatra install step from "appsignal install". PR #165
* Install Capistrano integration in `Capfile` instead of `deploy.rb`. #166
* More robust handing of non-writable log files. PR #160 #158
* Cleaner internal exception handling. PR #169 #170 #171 #172 #173
* Support for mixed case keywords in sql lexing. appsignal/sql_lexer#8
* Support for inserting multiple rows in sql lexing. appsignal/sql_lexer#9
* Add session_overview to JS transaction data.
  Commit af2d365bc124c01d7e9363e8d825404027835765

# 1.3.5

* Fix SSL certificate config in appsignal-agent. PR #151
* Remove mounted_at Sinatra middleware option. Now detected by default. PR #146
* Sinatra applications with middleware loading before AppSignal's middleware
  would crash a request. Fixed in PR #156

# 1.3.4

* Fix argument order for `record_event` in the AppSignal extension

# 1.3.3

* Output AppSignal environment on `appsignal diagnose`
* Prevent transaction crashes on Sinatra routes with optional parameters
* Listen to `stage` option to Capistrano 2 for automatic environment detection
* Add `appsignal_env` option to Capistrano 2 to set a custom environment

# 1.3.2
* Add method to discard a transaction
* Run spec suite with warnings, fixes for warnings

# 1.3.1
* Bugfix for problem when requiring config from installer

# 1.3.0
* Host metrics is now enabled by default
* Beta of minutely probes including GC metrics
* Refactor of param sanitization
* Param filtering for non-Rails frameworks
* Support for modular Sinatra applications
* Add Sinatra middleware to `Sinatra::Base` by default
* Allow a new transaction to be forced by sinatra instrumentation
* Allow hostname to be set with environment variable
* Helpers for easy method instrumentation
* `Appsignal.instrument` helper to easily instrument blocks of code
* `record_event` method to instrument events without a start hook
* `send_params` is now configurable via the environment
* Add DataMapper integration
* Add webmachine integration
* Allow overriding Padrino environment with APPSIGNAL_APP_ENV
* Add mkmf.log to diagnose command
* Allow for local install with bundler `bundle exec rake install`
* Listen to `stage` option to Capistrano 3 for automatic environment detection
* Add `appsignal_env` option to Capistrano 3 to set a custom environment

# 1.2.5
* Bugfix in CPU utilization calculation for host metrics

# 1.2.4
* Support for adding a namespace when mounting Sinatra apps in Rails
* Support for negative numbers and ILIKE in the sql lexer

# 1.2.3
* Catch nil config for installer and diag
* Minor performance improvements
* Support for arrays, literal value types and function arguments in sql lexer

# 1.2.2
* Handle out of range numbers in queue lenght and metrics api

# 1.2.1
* Use Dir.pwd in CLI install wizard
* Support bignums when setting queue length
* Support for Sequel 4.35
* Add env option to skip errors in Sinatra
* Fix for queue time calculation in Sidekiq (by lucasmazza)

# 1.2.0
* Restart background thread when FD's are closed
* Beta version of collecting host metrics (disabled by default)
* Hooks for Shuryoken
* Don't add errors from env if raise_errors is off for Sinatra

# 1.1.9
* Fix for race condition when creating working dir exactly at the same time
* Make diag Rake task resilient to missing config

# 1.1.8
* Require json to fix problem with using from Capistrano

# 1.1.7
* Make logging resilient for closing FD's (daemons gem does this)
* Add support for using Resque through ActiveJob
* Rescue more expections in json generation

# 1.1.6
* Generic Rack instrumentation middleware
* Event formatter for Faraday
* Rescue and log errors in transaction complete and fetching params

# 1.1.5
* Support for null in sql sanitization
* Add require to deploy.rb if present on installation
* Warn when overwriting already existing transaction
* Support for x86-linux
* Some improvements in debug logging
* Check of log file path is writable
* Use bundled CA certs when installing agent

# 1.1.4
* Better debug logging for agent issues
* Fix for exception with nil messages
* Fix for using structs as job params in Delayed Job

# 1.1.3
* Fix for issue where Appsignal.send_exception clears the current
  transaction if it is present
* Rails 3.0 compatibility fix

# 1.1.2
* Bug fix in notify of deploy cli
* Better support for nil, true and false in sanitization

# 1.1.1
* Collect global metrics for GC durations (in beta, disabled by default)
* Collect params from Delayed Job in a reliable way
* Collect perams for Delayed Job and Sidekiq when using ActiveJob
* Official Grape support
* Easier installation using `bundle exec appsignal install`

# 1.1.0
Yanked

# 1.0.7
* Another multibyte bugfix in sql sanizitation

# 1.0.6
* Bugfix in sql sanitization when using multibyte utf-8 characters

# 1.0.5
* Improved sql sanitization
* Improved mongoid/mongodb sanitization
* Minor performance improvements
* Better handling for non-utf8 convertable strings
* Make gem installable (but not functional) on jRuby

# 1.0.4
* Make working dir configurable using `APPSIGNAL_WORKING_DIR_PATH` or `:working_dir_path`

# 1.0.3
* Fix bug in completing JS transactions
* Make Resque integration robust for bigger payloads
* Message in logs if agent logging cannot initialize
* Call `to_s` on DJ id to see the id when using MongoDB

# 1.0.2
* Bug fix in format of process memory measurements
* Event formatter for `instantiation.active_record`
* Rake integration file for backwards compatibility
* Don't instrument mongo-ruby-driver when transaction is not present
* Accept method calls on extension if it's not loaded
* Fix for duplicate notifications subscriptions when forking

# 1.0.1
* Fix for bug in gem initialization when using `safe_yaml` gem

# 1.0.0
* New version of event formatting and collection
* Use native library and agent
* Use API V2
* Support for Mongoid 5
* Integration into other gems with a hooks system
* Lots of minor bug fixes and improvements

# 0.11.15
* Improve Sinatra support

# 0.11.14
* Support ActiveJob wrapped jobs
* Improve proxy support
* Improve rake support

# 0.11.13
* Add Padrino support
* Add Rake task monitoring
* Add http proxy support
* Configure Net::HTTP to only use TLS
* Don't send queue if there is no content
* Don't retry transmission when response code is 400 (no content)
* Don't start Resque IPC server when AppSignal is not active
* Display warning message when attempting to send a non-exception to `send_exception`
* Fix capistrano 2 detection
* Fix issue with Sinatra integration attempting to attach an exception to a transaction that doesn't exist.

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
