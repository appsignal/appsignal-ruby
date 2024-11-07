# AppSignal for Ruby gem Changelog

## 4.1.3

_Published on 2024-11-07._

### Added

- Add `activate_if_environment` helper for `Appsignal.configure`. Avoid having to add conditionals to your configuration file and use the `activate_if_environment` helper to specify for which environments AppSignal should become active. AppSignal will automatically detect the environment and activate itself it the environment matches one of the listed environments.

  ```ruby
  # Before
  Appsignal.configure do |config|
    config.active = Rails.env.production? || Rails.env.staging?
  end

  # After
  Appsignal.configure do |config|
    # Activate for one environment
    config.activate_if_environment(:production)

    # Activate for multiple environments
    config.activate_if_environment(:production, :staging)
  end
  ```

  (patch [ff31be88](https://github.com/appsignal/appsignal-ruby/commit/ff31be88cf49a18951f48663d96af3cde4184e32))
- Add a hostname AppSignal tag automatically, based on the OpenTelemetry `host.name` resource attribute. (Beta only) (patch [35449268](https://github.com/appsignal/appsignal-ruby/commit/35449268a5f6d7487d17018ddb8f5dd433d676e0))
- Add incident error count metric for enriched OpenTelemetry traces. (Beta only) (patch [35449268](https://github.com/appsignal/appsignal-ruby/commit/35449268a5f6d7487d17018ddb8f5dd433d676e0))
- Set the app revision config option for Scalingo deploys automatically. If the `CONTAINER_VERSION` system environment variable is present, it will use used to set the `revision` config option automatically. Overwrite it's value by configuring the `revision` config option for your application. (patch [35449268](https://github.com/appsignal/appsignal-ruby/commit/35449268a5f6d7487d17018ddb8f5dd433d676e0))

### Changed

- Ignore the Rails healthcheck endpoint (Rails::HealthController#show) by default for Rails apps.

  If the `ignore_actions` option is set in the `config/appsignal.yml` file, the default is overwritten.
  If the `APPSIGNAL_IGNORE_ACTIONS` environment variable is set, the default is overwritten.
  When using the `Appsignal.configure` helper, add more actions to the default like so:

  ```ruby
  # config/appsignal.rb
  Appsignal.configure do |config|
    # Add more actions to ignore
    config.ignore_actions << "My action"
  end
  ```

  To overwrite the default using the `Appsignal.configure` helper, do either of the following:

  ```ruby
  # config/appsignal.rb
  Appsignal.configure do |config|
    # Overwrite the default value, ignoring all actions ignored by default
    config.ignore_actions = ["My action"]

    # To only remove the healtcheck endpoint
    config.ignore_actions.delete("Rails::HealthController#show")
  end
  ```

  (patch [af71fb90](https://github.com/appsignal/appsignal-ruby/commit/af71fb904eebc4af05dc2fcf8bd390dd9baffd68))

### Fixed

- Fix an issue where the extension fails to build on ARM64 Linux. (patch [79ac5bbe](https://github.com/appsignal/appsignal-ruby/commit/79ac5bbe7028151ae749cbd7a4e98f706d259ad8))

## 4.1.2

_Published on 2024-10-04._

### Changed

- Change the primary download mirror for integrations. (patch [8fb8b93a](https://github.com/appsignal/appsignal-ruby/commit/8fb8b93af873735a33d9c9440260fd9afe9dd12b))
- Internal OpenTelemetry change. (patch [8fb8b93a](https://github.com/appsignal/appsignal-ruby/commit/8fb8b93af873735a33d9c9440260fd9afe9dd12b))

### Fixed

- Fix session data reporting for Action Cable actions. (patch [41642bea](https://github.com/appsignal/appsignal-ruby/commit/41642beace7e65f441a93319fbd94192c4d5aedf))

## 4.1.1

_Published on 2024-09-28._

### Changed

- Add the `reported_by` tag to errors reported by the Rails error reporter so the source of the error is easier to identify. (patch [ff98ed67](https://github.com/appsignal/appsignal-ruby/commit/ff98ed677bf30242c51261bf7e44c9b6ba2f33ac))

### Fixed

- Fix no AppSignal internal logs being logged from Capistrano tasks. (patch [089d0325](https://github.com/appsignal/appsignal-ruby/commit/089d03251c3dc8b83658a4ebfade51ab6bed1771))
- Report all the config options set via `Appsignal.config` in the DSL config source in the diagnose report. Previously, it would only report the options from the last time `Appsignal.configure` was called. (patch [27b9aff7](https://github.com/appsignal/appsignal-ruby/commit/27b9aff7776646dfef6c55fa589024a71052e70b))
- Fix 'no implicit conversion of Pathname into String' error when parsing backtrace lines of error causes in Rails apps. (patch [b767f269](https://github.com/appsignal/appsignal-ruby/commit/b767f269c41cb7625d6869d8e8acb9b288292d19))

## 4.1.0

_Published on 2024-09-26._

### Added

- Add support for heartbeat check-ins.

  Use the `Appsignal::CheckIn.heartbeat` method to send a single heartbeat check-in event from your application. This can be used, for example, in your application's main loop:

  ```ruby
  loop do
    Appsignal::CheckIn.heartbeat("job_processor")
    process_job
  end
  ```

  Heartbeats are deduplicated and sent asynchronously, without blocking the current thread. Regardless of how often the `.heartbeat` method is called, at most one heartbeat with the same identifier will be sent every ten seconds.

  Pass `continuous: true` as the second argument to send heartbeats continuously during the entire lifetime of the current process. This can be used, for example, after your application has finished its boot process:

  ```ruby
  def main
    start_app
    Appsignal::CheckIn.heartbeat("my_app", continuous: true)
  end
  ```

  (minor [7ae7152c](https://github.com/appsignal/appsignal-ruby/commit/7ae7152cddae7c257e9d62d3bf2433cce1f4287d))
- Include the first backtrace line from error causes to show where each cause originated in the interface. (patch [496b035a](https://github.com/appsignal/appsignal-ruby/commit/496b035a3510dbb6dc47c7c59172f488ec55c986))

## 4.0.9

_Published on 2024-09-17._

### Changed

- Add the logger gem as a dependency. This fixes the deprecation warning on Ruby 3.3. (patch [8c1d577e](https://github.com/appsignal/appsignal-ruby/commit/8c1d577e4790185db887d49577cedc7d614d8d98))
- Do not report errors caused by `Errno::EPIPE` (broken pipe errors) when instrumenting response bodies, to avoid reporting errors that cannot be fixed by the application. (patch [1fdccba4](https://github.com/appsignal/appsignal-ruby/commit/1fdccba4ceeb8f9bb13ae077019b2c1f7d9d4fe4))
- Normalize Rack and Rails `UploadedFile` objects. Instead of displaying the Ruby class name, it will now show object details like the filename and content type.

  ```
  # Before
  #<Rack::Multipart::UploadedFile>
  #<ActionDispatch::Http::UploadedFile>

  # After
  #<Rack::Multipart::UploadedFile original_filename: "uploaded_file.txt", content_type: "text/plain">
  #<ActionDispatch::Http::UploadedFile original_filename: "uploaded_file.txt", content_type: "text/plain">
  ```

  (patch [bb50c933](https://github.com/appsignal/appsignal-ruby/commit/bb50c93387eafebe043b0e7f4083c95556b93136))

## 4.0.8

_Published on 2024-09-13._

### Fixed

- Fix a `ThreadError` from being raised on process exit when `Appsignal.stop` is called from a `Signal.trap` block, like when Puma shuts down in clustered mode. (patch [32323ded](https://github.com/appsignal/appsignal-ruby/commit/32323ded277d4764ea1bd0d0dab02bef3de40ccb))

## 4.0.7

_Published on 2024-09-12._

### Changed

- Format the Date and Time objects in a human-friendly way. Previously, dates and times stored in sample data, like session data, would be shown as `#<Date>` and `#<Time>`. Now they will show as `#<Date: 2024-09-11>` and `#<Time: 2024-09-12T13:14:15+02:00>` (UTC offset may be different for your time objects depending on the server setting). (patch [8f516484](https://github.com/appsignal/appsignal-ruby/commit/8f516484d249f43ffadcf15a67bbab48f827eff6))

### Removed

- Do not include support files in the published versions. This reduces the gem package size. (patch [fb729329](https://github.com/appsignal/appsignal-ruby/commit/fb7293295279dd43ed81342dae5bb0f95b8f3714))

## 4.0.6

_Published on 2024-09-03._

### Added

- Add support for Que 2 keyword arguments. Que job arguments will now be reported as the `arguments` key for positional arguments and `keyword_arguments` for Ruby keyword arguments. (patch [770bdc06](https://github.com/appsignal/appsignal-ruby/commit/770bdc06c352de09757edc92ee06b7c999befaee))

## 4.0.5

_Published on 2024-09-02._

### Added

- Report Puma low-level errors using the `lowlevel_error` reporter. This will report errors previously not caught by our instrumentation middleware. (patch [70cc21f4](https://github.com/appsignal/appsignal-ruby/commit/70cc21f49e19faa9fd2d12a051620cd48e036dcb))

### Changed

- Log a warning when loader defaults are added after AppSignal has already been configured.

  ```ruby
  # Bad
  Appsignal.configure # or Appsignal.start
  Appsignal.load(:sinatra)

  # Good
  Appsignal.load(:sinatra)
  Appsignal.configure # or Appsignal.start
  ```

  (patch [0997dd9c](https://github.com/appsignal/appsignal-ruby/commit/0997dd9c0430123a697b8100785f5676163e20ef))
- Rename the `path` and `method` transaction metadata to `request_path` and `request_method` to make it more clear what context this metadata is from. The `path` and `method` metadata will continue to be reported until the next major/minor version. (patch [fa314b5f](https://github.com/appsignal/appsignal-ruby/commit/fa314b5fb6fdfbf3e9746df377b0145cde0cfa36))
- Internal change to how OpenTelemetry metrics are sent. (patch [e66d1d70](https://github.com/appsignal/appsignal-ruby/commit/e66d1d702d5010cb5b8084ba790b24d9e70a9e08))

### Removed

- Drop support for Puma version 2 and lower. (patch [4fab861c](https://github.com/appsignal/appsignal-ruby/commit/4fab861cae74b08aa71bf64e1b134ae4b1df1dff))

### Fixed

- Fix the error log message about our `at_exit` hook reporting no error on process exit when the process exits without an error. (patch [b71f3966](https://github.com/appsignal/appsignal-ruby/commit/b71f39661e9b05c10fa78b821ba0e45bde0c941b))

## 4.0.4

_Published on 2024-08-29._

### Changed

- Send check-ins concurrently. When calling `Appsignal::CheckIn.cron`, instead of blocking the current thread while the check-in events are sent, schedule them to be sent in a separate thread.

  When shutting down your application manually, call `Appsignal.stop` to block until all scheduled check-ins have been sent.

  (patch [46d4ca74](https://github.com/appsignal/appsignal-ruby/commit/46d4ca74f4c188cc011653ed23969ad7ec770812))

### Fixed

- Make our Rack BodyWrapper behave like a Rack BodyProxy. If a method doesn't exist on our BodyWrapper class, but it does exist on the body, behave like the Rack BodyProxy and call the method on the wrapped body. (patch [e2376305](https://github.com/appsignal/appsignal-ruby/commit/e23763058a3fb980f1054e9c1eaf7e0f25f75666))
- Do not report `SignalException` errors from our `at_exit` error reporter. (patch [3ba3ce31](https://github.com/appsignal/appsignal-ruby/commit/3ba3ce31ee3f3e84665c9f2f18d488c689cff6c2))

## 4.0.3

_Published on 2024-08-26._

### Changed

- Do not report Sidekiq `Sidekiq::JobRetry::Handled` and `Sidekiq::JobRetry::Skip` errors. These errors would be reported by our Rails error subscriber. These are an internal Sidekiq errors we do not need to report. (patch [e385ee2c](https://github.com/appsignal/appsignal-ruby/commit/e385ee2c4da13063e6f1a7a207286dda74113fc4))

### Removed

- Remove the `app_path` writer in the `Appsignal.configure` helper. This was deprecated in version 3.x. It is removed now in the next major version.

  Use the `root_path` keyword argument in the `Appsignal.configure` helper (`Appsignal.configure(:root_path => "...")`) to change the AppSignal root path if necessary.

  (patch [6335da6d](https://github.com/appsignal/appsignal-ruby/commit/6335da6d99a5ba7687fb5885eee27b9633d80474))

## 4.0.2

_Published on 2024-08-23._

### Fixed

- Do not log a warning for `nil` data being added as sample data, but silently ignore it because we don't support it. (patch [0a658e5e](https://github.com/appsignal/appsignal-ruby/commit/0a658e5e523f23f87b7d6e0b88bf6d6bea529f06))
- Fix Rails session data not being reported. (patch [1565c7f0](https://github.com/appsignal/appsignal-ruby/commit/1565c7f0a55e8c2e51b615863b12d13a2b246949))

## 4.0.1

_Published on 2024-08-23._

### Fixed

- Do not report `Sidekiq::JobRetry::Skip` errors. These errors would be reported by our Rails error subscriber. This is an internal Sidekiq error we do not need to report. (patch [9ea2d3e8](https://github.com/appsignal/appsignal-ruby/commit/9ea2d3e83657d115baf166257a50c7e3394318aa))
- Do not report `SystemExit` errors from our `at_exit` error reporter. (patch [e9c0cad3](https://github.com/appsignal/appsignal-ruby/commit/e9c0cad3d672e68a63ca9c33cfa30a3434c77d04))

## 4.0.0

_Published on 2024-08-23._

### Changed

- Release the final package version. See the pre-release changelog entries for the changes in this version. (major)

### Removed

- Remove the `Transaction.new` method Transaction ID argument. The Transaction ID will always be automatically generated. (major [bb938a9f](https://github.com/appsignal/appsignal-ruby/commit/bb938a9f79b8b51e4c47d3f268326f89c137df6f))

## 4.0.0.beta.2

_Published on 2024-08-19._

### Added

- Add a helper for parameters sample data to be unset. This is a private method until we stabilize it. (patch [e9336363](https://github.com/appsignal/appsignal-ruby/commit/e9336363fa869c88ab925f57e86ead45e8e18c29))

## 4.0.0.beta.1

_Published on 2024-08-19._

### Added

- Add an `at_exit` callback error reporter. By default, AppSignal will now report any unhandled errors that crash the process as long as Appsignal started beforehand.

  ```ruby
  require "appsignal"

  Appsignal.start

  raise "oh no!"

  # Will report the error StandardError "oh no!"
  ```

  To disable this behavior, set the `enable_at_exit_reporter` config option to `false`.

  (major [5124b0e9](https://github.com/appsignal/appsignal-ruby/commit/5124b0e903f04a5aff5bfaeaa7ff174170b413e7))
- Report errors from Rails runners. When a Rails runner reports an unhandled error, it will now report the error in the "runner" namespace. (minor [4d6add1d](https://github.com/appsignal/appsignal-ruby/commit/4d6add1d92255b8e1e6c8187f70258477dc05027))
- Support adding multiple errors to a transaction.

  Using the `Appsignal.report_error` helper, you can now report more than one error within the same transaction context, up to a maximum of ten errors per transaction. Each error will be reported as a separate sample in the AppSignal UI.

  Before this change, using `Appsignal.report_error` or `Appsignal.set_error` helpers, adding a new error within the same transaction would overwrite the previous one.

  (patch [70ffc00a](https://github.com/appsignal/appsignal-ruby/commit/70ffc00ad31b19c2b91a915f58e3db4c9857201b))

### Changed

- Change the default Rake task namespace to "rake". Previously, Rake tasks were reported in the "background" namespace. (major [7673b13c](https://github.com/appsignal/appsignal-ruby/commit/7673b13c933f1944d94d780bb6943cb2c7036a4d))
- Do not start AppSignal when the config file raises an error. Previously, the file source would be ignored. (major [17933fd9](https://github.com/appsignal/appsignal-ruby/commit/17933fd90e9236ca1f825bb76f849b0daf066498))
- Freeze the config after AppSignal has started. Prevent the config from being modified after AppSignal has started to avoid the expectation that modifying the config after starting AppSignal has any effect. (major [46f23f15](https://github.com/appsignal/appsignal-ruby/commit/46f23f15035e0bb56fd099f4c304960437e5afce))
- Do not start Appsignal multiple times if `Appsignal.start` is called more than once. The configuration can no longer be modified after AppSignal has started. (major [fbc2410a](https://github.com/appsignal/appsignal-ruby/commit/fbc2410a9a7e0d9b40240fc3e7e7557ed0a001c0))
- The transaction sample data is now merged by default. Previously, the sample data (except for tags) would be overwritten when a sample data helper was called.

  ```ruby
  # Old behavior
  Appsignal.set_params("param1" => "value")
  Appsignal.set_params("param2" => "value")
  # The parameters are:
  # { "param2" => "value" }


  # New behavior
  Appsignal.add_params("param1" => "value")
  Appsignal.add_params("param2" => "value")
  # The parameters are:
  # {  "param1" => "value", "param2" => "value" }
  ```

  New helpers have been added:

  - `Appsignal.add_tags`
  - `Appsignal.add_params`
  - `Appsignal.add_session_data`
  - `Appsignal.add_headers`
  - `Appsignal.add_custom_data`

  The old named helpers that start with `set_` will still work. They will also use the new merging behavior.

  (major [272f18cb](https://github.com/appsignal/appsignal-ruby/commit/272f18cb0fde6c77fce8b9fa32b4888216e55381))
- Set the Rails config defaults for `Appsignal.configure` when used in a Rails initializer. Now when using `Appsignal.configure` in a Rails initializer, the Rails env and root path are set on the AppSignal config as default values and do not need to be manually set. (major [378bbc3e](https://github.com/appsignal/appsignal-ruby/commit/378bbc3e0d809f238f6a8a77ee401f73f0b9bd89))
- Global transaction metadata helpers now work inside the `Appsignal.report_error` and `Appsignal.send_error` callbacks. The transaction yield parameter will continue to work, but we recommend using the global `Appsignal.set_*` and `Appsignal.add_*` helpers.

  ```ruby
  # Before
  Appsignal.report_error(error) do |transaction|
    transaction.set_namespace("my namespace")
    transaction.set_action("my action")
    transaction.add_tags(:tag_a => "value", :tag_b => "value")
    # etc.
  end
  Appsignal.send_error(error) do |transaction|
    transaction.set_namespace("my namespace")
    transaction.set_action("my action")
    transaction.add_tags(:tag_a => "value", :tag_b => "value")
    # etc.
  end

  # After
  Appsignal.report_error(error) do
    Appsignal.set_namespace("my namespace")
    Appsignal.set_action("my action")
    Appsignal.add_tags(:tag_a => "value", :tag_b => "value")
    # etc.
  end
  Appsignal.send_error(error) do
    Appsignal.set_namespace("my namespace")
    Appsignal.set_action("my action")
    Appsignal.add_tags(:tag_a => "value", :tag_b => "value")
    # etc.
  end
  ```

  (major [7ca6ce21](https://github.com/appsignal/appsignal-ruby/commit/7ca6ce215844f43e9d1277dcce18921f2e716158))
- Include the Rails app config in diagnose report. If AppSignal is configured in a Rails initializer, this config is now included in the diagnose report. (minor [5439d5cb](https://github.com/appsignal/appsignal-ruby/commit/5439d5cbc6661c705da0d1feb08738c933f56939))
- Include the config options from the loaders config defaults and the `Appsignal.configure` helper in diagnose report. The sources for config option values will include the loaders and `Appsignal.configure` helper in the output and the JSON report sent to our severs, when opted-in. (patch [a7b34110](https://github.com/appsignal/appsignal-ruby/commit/a7b34110ac47e200a6f136c3706e31fe93d37122))
- Calculate error rate by transactions with an error, not the number of errors on a transaction. This limits the error rate to a maximum of 100%. (patch [da4975cd](https://github.com/appsignal/appsignal-ruby/commit/da4975cd0dda27e3966266f1a686787609fbbcd2))

### Removed

- Remove all deprecated components. Please follow [our Ruby gem 4 upgrade guide](https://docs.appsignal.com/ruby/installation/upgrade-from-3-to-4.html) when upgrading to this version to avoid any errors from calling removed components, methods and helpers. (major [f65bee8d](https://github.com/appsignal/appsignal-ruby/commit/f65bee8d508feae4cba88bd938b297e15269726f))
- Remove the `Appsignal.listen_for_error` helper. Use manual exception handling using `rescue => error` with the `Appsignal.report_error` helper instead. (major [7c232925](https://github.com/appsignal/appsignal-ruby/commit/7c23292568035eace8d04e3fb53e8d4861b671e6))
- Remove (private) `Appsignal::Transaction::FRONTEND` constant. This was previously used for the built-in front-end integration, but this has been absent since version 3 of the Ruby gem. (major [c12188e7](https://github.com/appsignal/appsignal-ruby/commit/c12188e7cf5f9adccb485a5930f3bdbbe1b6cc58))
- Remove the `Appsignal.config=` writer. Use the `Appsignal.configure` helper to configure AppSignal. (major [f4fdf91b](https://github.com/appsignal/appsignal-ruby/commit/f4fdf91b5ead5c5221f5dbad6d8c45069ee2dc98))

### Fixed

- Fix an issue where, when setting several errors for the same transaction, error causes from a different error would be shown for an error that has no causes. (patch [d54ce8b9](https://github.com/appsignal/appsignal-ruby/commit/d54ce8b947c9316756c4191155e8d255a8e25a8c))

## 3.13.1

_Published on 2024-08-23._

### Changed

- Release the final package version. See the pre-release changelog entries for the changes in this version. (patch)

## 3.13.1.alpha.1

_Published on 2024-08-22._

### Changed

- Ignore `Errno::EPIPE` errors when instrumenting response bodies. We've noticed this error gets reported when the connection is broken between server and client. This happens in normal scenarios so we'll ignore this error in this scenario to avoid error reports from errors that cannot be resolved. (patch [8ad8a057](https://github.com/appsignal/appsignal-ruby/commit/8ad8a05787dcb12a5c7febc64559e7f145a59096))

## 3.13.0

_Published on 2024-08-14._

### Changed

- Remove the HTTP gem's exception handling. Errors from the HTTP gem will no longer always be reported. The error will be reported only when an HTTP request is made in an instrumented context. This gives applications the opportunity to add their own custom exception handling.

  ```ruby
  begin
    HTTP.get("https://appsignal.com/error")
  rescue => error
    # Either handle the error or report it to AppSignal
  end
  ```

  (minor [2a452ff0](https://github.com/appsignal/appsignal-ruby/commit/2a452ff07e0b0938b1623fa8846af6ef37917ec2))
- Rename heartbeats to cron check-ins. Calls to `Appsignal.heartbeat` and `Appsignal::Heartbeat` should be replaced with calls to `Appsignal::CheckIn.cron` and `Appsignal::CheckIn::Cron`, for example:

  ```ruby
  # Before
  Appsignal.heartbeat("do_something") do
    do_something
  end

  # After
  Appsignal::CheckIn.cron("do_something") do
    do_something
  end
  ```

  (patch [2f686cd0](https://github.com/appsignal/appsignal-ruby/commit/2f686cd00d5daa6e0854a8cacfe0e874a3a7c146))

### Deprecated

- Calls to `Appsignal.heartbeat` and `Appsignal::Heartbeat` will emit a deprecation warning. (patch [2f686cd0](https://github.com/appsignal/appsignal-ruby/commit/2f686cd00d5daa6e0854a8cacfe0e874a3a7c146))

## 3.12.6

_Published on 2024-08-05._

### Changed

- Configure AppSignal with the install CLI when no known frameworks is found. Automate the configure step so that this doesn't have to be done manually along with the manual setup for the app. (patch [a9c546fa](https://github.com/appsignal/appsignal-ruby/commit/a9c546fa86afbec290cd8439a559bf60cad21fc8))

### Deprecated

- Deprecate the `Appsignal.listen_for_error` helper. Use a manual error rescue with `Appsignal.report_error`. This method allows for more customization of the reported error.

  ```ruby
  # Before
  Appsignal.listen_for_error do
    raise "some error"
  end

  # After
  begin
    raise "some error"
  rescue => error
    Appsignal.report_error(error)
  end
  ```

  Read our [Exception handling guide](https://docs.appsignal.com/ruby/instrumentation/exception-handling.html) for more information.

  (patch [14bd8882](https://github.com/appsignal/appsignal-ruby/commit/14bd88824dea2993cb0165bbbed0def29d69f72a))
- Deprecate the `Appsignal.configure`'s `app_path` writer. Use the `Appsignal.configure`'s `root_path` keyword argument to configure the path. (patch [c79f46c3](https://github.com/appsignal/appsignal-ruby/commit/c79f46c3cd96ac51726a963f38999bfb3c246d52))

### Fixed

- Fix an error on the Padrino require in the installer CLI. The latest Padrino version will crash the installer on load. Ignore the error when it fails to load. (patch [dfe23707](https://github.com/appsignal/appsignal-ruby/commit/dfe23707f769ff818714ee7cf14340f9472ce2e4))
- Fix the `Appsignal.configure` path config not being customizable. It's now possible to pass a `root_path` keyword argument to `Appsignal.configure` to customize the path from which AppSignal reads the config file, `config/appsignal.yml`. (patch [c79f46c3](https://github.com/appsignal/appsignal-ruby/commit/c79f46c3cd96ac51726a963f38999bfb3c246d52))

## 3.12.5

_Published on 2024-08-01._

### Changed

- Improve sanitization of INSERT INTO ... VALUES with multiple groups by removing additional repeated groups.

  This makes the query easier to read, and mitigates an issue where processing many events with slightly distinct queries would cause some event details to de discarded.

  (patch [45a20433](https://github.com/appsignal/appsignal-ruby/commit/45a20433fc7ead962d998f4218d0904cfb501a7c))

### Fixed

- Fix issue sanitizing SQL queries containing TRUE and FALSE values in an INSERT INTO ... VALUES clause. (patch [45a20433](https://github.com/appsignal/appsignal-ruby/commit/45a20433fc7ead962d998f4218d0904cfb501a7c))

## 3.12.4

_Published on 2024-08-01._

### Fixed

- Fix an issue where, depending on the relative order of the `appsignal` and `view_component` dependencies in the Gemfile, the ViewComponent instrumentation would not load. (patch [0f37fa30](https://github.com/appsignal/appsignal-ruby/commit/0f37fa30dec66cccb68755d332e835487e8fd039))

## 3.12.3

_Published on 2024-07-30._

### Fixed

- Fix the application environment being reported as "[]" when no valid environment could be found. (patch [cf081253](https://github.com/appsignal/appsignal-ruby/commit/cf0812536e0651ee5b62427847a4244d4640e22b))
- Fix `Appsignal.configure` call without `env` argument not reusing the previously configured configuration. (patch [65d5428c](https://github.com/appsignal/appsignal-ruby/commit/65d5428c4d41f683a796b67b0ae339a0d213c802))

## 3.12.2

_Published on 2024-07-25._

### Fixed

- Fix the default env and root path for the integrations using loader mechanism. If `APPSIGNAL_APP_ENV` is set when using `Appsignal.load(...)`, the AppSignal env set in `APPSIGNAL_APP_ENV` is now leading again. (patch [b2d1c7ee](https://github.com/appsignal/appsignal-ruby/commit/b2d1c7ee082e6865d9dc8d23ef060ecec9197a0e))

## 3.12.1

_Published on 2024-07-25._

### Fixed

- Fix `Appsignal.monitor_and_stop` block passing. It would error with a `LocalJumpError`. Thanks to @cwaider. (patch [150569ff](https://github.com/appsignal/appsignal-ruby/commit/150569ff49e54ab743ed3db16d109abcf5719e30))

## 3.12.0

_Published on 2024-07-22._

### Added

- Add a Rails configuration option to start AppSignal after Rails is initialized. By default, AppSignal will start before the Rails initializers are run. This way it is not possible to configure AppSignal in a Rails initializer using Ruby. To configure AppSignal in a Rails initializer, configure Rails to start AppSignal after it is initialized.

  ```ruby
  # config/application.rb

  # ...

  module MyApp
    class Application < Rails::Application
      # Add this line
      config.appsignal.start_at = :after_initialize

      # Other config
    end
  end
  ```

  Then, in the initializer:

  ```ruby
  # config/initializers/appsignal.rb

  Appsignal.configure do |config|
    config.ignore_actions = ["My action"]
  end
  ```

  Be aware that when `start_at` is set to `after_initialize`, AppSignal will not track any errors that occur when the initializers are run and the app fails to start.

  See [our Rails documentation](https://docs.appsignal.com/ruby/integrations/rails.html) for more information.

  (minor [b84a6a36](https://github.com/appsignal/appsignal-ruby/commit/b84a6a3695259b365cde6f69165818a1e1b99197))
- Add a new method of configuring AppSignal: `Appsignal.configure`. This new method allows apps to configure AppSignal in Ruby.

  ```ruby
  # The environment will be auto detected
  Appsignal.configure do |config|
    config.activejob_report_errors = "discard"
    config.sidekiq_report_errors = :discard
    config.ignore_actions = ["My ignored action", "My other ignored action"]
    config.request_headers << "MY_HTTP_HEADER"
    config.send_params = true
    config.enable_host_metrics = false
  end

  # Explicitly define which environment to start
  Appsignal.configure(:production) do |config|
    # Some config
  end
  ```

  This new method can be used to update config in Ruby. We still recommend to use the `config/appsignal.yml` file to configure AppSignal whenever possible. Apps that use the `Appsignal.config = Appsignal::Config.new(...)` way of configuring AppSignal, should be updated to use the new `Appsignal.configure` method. The `Appsignal::Config.new` method would overwrite the given "initial config" with the config file's config and config read from environment variables. The `Appsignal.configure` method is leading. The config file, environment variables and `Appsignal.configure` methods can all be mixed.

  See [our configuration guide](https://docs.appsignal.com/ruby/configuration.html) for more information.

  (minor [ba60fff9](https://github.com/appsignal/appsignal-ruby/commit/ba60fff9fa5087c78e171a0608beba882e1a4c92))

### Changed

- Update the Sinatra, Padrino, Grape and Hanami integration setup for applications. Before this change a "appsignal/integrations/sinatra" file would need to be required to load the AppSignal integration for Sinatra. Similar requires exist for other libraries. This has changed to a new integration load mechanism.

  This new load mechanism makes starting AppSignal more predictable when loading multiple integrations, like those for Sinatra, Padrino, Grape and Hanami.

  ```ruby
  # Sinatra example
  # Before
  require "appsignal/integrations/sinatra"

  # After
  require "appsignal"

  Appsignal.load(:sinatra)
  Appsignal.start
  ```

  The `require "appsignal/integrations/sinatra"` will still work, but is deprecated in this release.

  See the documentation for the specific libraries for the latest on how to integrate AppSignal.

  - [Grape](https://docs.appsignal.com/ruby/integrations/grape.html)
  - [Hanami](https://docs.appsignal.com/ruby/integrations/hanami.html)
  - [Padrino](https://docs.appsignal.com/ruby/integrations/padrino.html)
  - [Sinatra](https://docs.appsignal.com/ruby/integrations/sinatra.html)

  When using a combination of the libraries listed above, read our [integration guide](https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html) on how to load and configure AppSignal for multiple integrations at once.

  (minor [35fff8cb](https://github.com/appsignal/appsignal-ruby/commit/35fff8cb135bf024b3bcf95e497af7dcc0a4cc02))
- Disable the AppSignal Rack EventHandler when AppSignal is not active. It would still trigger our instrumentation when AppSignal is not active. This reduces the instrumentation overhead when AppSignal is not active. (patch [03e7c1b2](https://github.com/appsignal/appsignal-ruby/commit/03e7c1b221caa00af1599ae94e1d4055835c94a7))

### Deprecated

- Deprecate the `Appsignal.config = Appsignal::Config.new(...)` method of configuring AppSignal. See the changelog entry about `Appsignal.configure { ... }` for the new way to configure AppSignal in Ruby. (minor [ba60fff9](https://github.com/appsignal/appsignal-ruby/commit/ba60fff9fa5087c78e171a0608beba882e1a4c92))
- Deprecate the Hanami integration require: `require "appsignal/integrations/hanami"`. Use the new `Appsignal.load(:hanami)` method instead. Read our [Hanami docs](https://docs.appsignal.com/ruby/integrations/hanami.html) for more information. (patch)
- Deprecate the Padrino integration require: `require "appsignal/integrations/padrino"`. Use the new `Appsignal.load(:padrino)` method instead. Read our [Padrino docs](https://docs.appsignal.com/ruby/integrations/padrino.html) for more information. (patch)
- Deprecate the Sinatra integration require: `require "appsignal/integrations/sinatra"`. Use the new `Appsignal.load(:sinatra)` method instead. Read our [Sinatra docs](https://docs.appsignal.com/ruby/integrations/sinatra.html) for more information. (patch)
- Deprecate the Grape integration require: `require "appsignal/integrations/grape"`. Use the new `Appsignal.load(:grape)` method instead. Read our [Grape docs](https://docs.appsignal.com/ruby/integrations/grape.html) for more information. (patch)

### Fixed

- Fix instrumentation events for response bodies appearing twice. When multiple instrumentation middleware were mounted in an application, it would create duplicate `process_response_body.rack` events. (patch [24b16517](https://github.com/appsignal/appsignal-ruby/commit/24b16517f3bf5e2911345d5d825a1febb3c7aed7))

## 3.11.0

_Published on 2024-07-15._

### Added

- Add `Appsignal.monitor` and `Appsignal.monitor_and_stop` instrumentation helpers. These helpers are a replacement for the `Appsignal.monitor_transaction` and `Appsignal.monitor_single_transaction` helpers.

  Use these new helpers to create an AppSignal transaction and track any exceptions that occur within the instrumented block. This new helper supports custom namespaces and has a simpler way to set an action name. Use this helper in combination with our other `Appsignal.set_*` helpers to add more metadata to the transaction.

  ```ruby
  # New helper
  Appsignal.monitor(
    :namespace => "my_namespace",
    :action => "MyClass#my_method"
  ) do
    # Track an instrumentation event
    Appsignal.instrument("my_event.my_group") do
      # Some code
    end
  end

  # Old helper
  Appsignal.monitor_transaction(
    "process_action.my_group",
    :class_name => "MyClass",
    :action_name => "my_method"
  ) do
    # Some code
  end
  ```

  The `Appsignal.monitor_and_stop` helper can be used in the same scenarios as the `Appsignal.monitor_single_transaction` helper is used. One-off Ruby scripts that are not part of a long running process.

  Read our [instrumentation documentation](https://docs.appsignal.com/ruby/instrumentation/background-jobs.html) for more information about using the`Appsignal.monitor` helper.

  (minor [f38f0cff](https://github.com/appsignal/appsignal-ruby/commit/f38f0cff978c7e7244beae347a8355fff19b13f1))
- Add `Appsignal.set_session_data` helper. Set custom session data on the current transaction with the `Appsignal.set_session_data` helper. Note that this will overwrite any request session data that would be set automatically on the transaction. When this method is called multiple times, it will overwrite the previously set value.

  ```ruby
  Appsignal.set_session_data("data1" => "value1", "data2" => "value2")
  ```

  (patch [48c76635](https://github.com/appsignal/appsignal-ruby/commit/48c76635043a3777de79816bdb2154ad392c1b09))
- Add `Appsignal.set_headers` helper. Set custom request headers on the current transaction with the `Appsignal.set_headers` helper. Note that this will overwrite any request headers that would be set automatically on the transaction. When this method is called multiple times, it will overwrite the previously set value.

  ```ruby
  Appsignal.set_headers("PATH_INFO" => "/some-path", "HTTP_USER_AGENT" => "Firefox")
  ```

  (patch [7d82dffd](https://github.com/appsignal/appsignal-ruby/commit/7d82dffd75a6c7c9a8b6a8fac7e6bbb70104b63c))
- Report request headers for webmachine apps. (patch [fcfb7a0d](https://github.com/appsignal/appsignal-ruby/commit/fcfb7a0d2545a2144aa61efa61d445c0e11c7749))

### Changed

- Allow tags to have boolean (true/false) values.

  ```ruby
  Appsignal.set_tags("my_tag_is_amazing" => true)
  Appsignal.set_tags("my_tag_is_false" => false)
  ```

  (patch [1b8e86cb](https://github.com/appsignal/appsignal-ruby/commit/1b8e86cba3472ebec78680ca6a2ed8aa76938724))
- Optimize Sidekiq job arguments being recorded. Job arguments are only fetched and set when we sample the job transaction, which should decrease our overhead for all jobs we don't sample. (patch [3f957301](https://github.com/appsignal/appsignal-ruby/commit/3f95730145d6eef7eb13901853685e4d56d5495c))

### Deprecated

- Deprecate Transaction sample helpers: `Transaction#set_sample_data` and `Transaction#sample_data`. Please use one of the other sample data helpers instead. See our [sample data guide](https://docs.appsignal.com/guides/custom-data/sample-data.html). (patch [2d2e0e43](https://github.com/appsignal/appsignal-ruby/commit/2d2e0e43c9125b4566e3265b6e6ae85e4910652b))
- Deprecate the `Appsignal::Transaction#set_http_or_background_queue_start` method. Use the `Appsignal::Transaction#set_queue_start` helper instead. (patch [d93e0370](https://github.com/appsignal/appsignal-ruby/commit/d93e0370ff4e37cf8d12652a6e5cca66651a5790))
- Deprecate the `Appsignal.without_instrumentation` helper. Use the `Appsignal.ignore_instrumentation_events` helper instead. (patch [7cc3c0e4](https://github.com/appsignal/appsignal-ruby/commit/7cc3c0e41615394deec348d5e0a40b7a6c1fc1d9))
- Deprecate the `Appsignal::Transaction::GenericRequest` class. Use the `Appsignal.set_*` helpers to set metadata on the Transaction instead. Read our [sample data guide](https://docs.appsignal.com/guides/custom-data/sample-data.html) for more information. (patch [1c69d3fd](https://github.com/appsignal/appsignal-ruby/commit/1c69d3fdf47959c240c4732f7e8551802a9eba63))
- Deprecate the 'ID', 'request', and 'options' arguments for the `Transaction.create` and `Transaction.new` methods. To add metadata to the transaction, use the `Appsignal.set_*` helpers. Read our [sample data guide](https://docs.appsignal.com/guides/custom-data/sample-data.html) for more information on how to set metadata on transactions.

  ```ruby
  # Before
  Appsignal::Transaction.create(
    SecureRandom.uuid,
    "my_namespace",
    Appsignal::Transaction::GenericRequest.new(env) # env is a request env Hash
  )

  # After
  Appsignal::Transaction.create("my_namespace")
  ```

  (patch [2fc2c617](https://github.com/appsignal/appsignal-ruby/commit/2fc2c617321bc6a520205cae0cfa42fb3c8fc5d8))
- Deprecate the `Appsignal.monitor_transaction` and `Appsignal.monitor_single_transaction` helpers. See the entry about the replacement helpers `Appsignal.monitor` and `Appsignal.monitor_and_stop`. (patch [470d5813](https://github.com/appsignal/appsignal-ruby/commit/470d58132270115215093c9cffd16e52829ef4c4))

## 3.10.0

_Published on 2024-07-08._

### Added

- Add our new recommended Rack instrumentation middleware. If an app is using the `Appsignal::Rack::GenericInstrumentation` middleware, please update it to use `Appsignal::Rack::InstrumentationMiddleware` instead.

  This new middleware will not report all requests under the "unknown" action if no action name is set. To set an action name, call the `Appsignal.set_action` helper from the app.

  ```ruby
  # config.ru

  # Setup AppSignal

  use Appsignal::Rack::InstrumentationMiddleware

  # Run app
  ```

  (minor [f2596781](https://github.com/appsignal/appsignal-ruby/commit/f259678111067bd3d7cf60552201f4d4f95a99d6))
- Add Rake task performance instrumentation. Configure the `enable_rake_performance_instrumentation` option to `true` to enable Rake task instrumentation for both error and performance monitoring. To ignore specific Rake tasks, configure `ignore_actions` to include the name of the Rake task. (minor [63c9aeed](https://github.com/appsignal/appsignal-ruby/commit/63c9aeed978fcd0942238772c2e441b33e12e16a))
- Add instrumentation to Rack responses, including streaming responses. New `process_response_body.rack` and `close_response_body.rack` events will be shown in the event timeline. These events show how long it takes to complete responses, depending on the response implementation, and when the response is closed.

  This Sinatra route with a streaming response will be better instrumented, for example:

  ```ruby
  get "/stream" do
    stream do |out|
      sleep 1
      out << "1"
      sleep 1
      out << "2"
      sleep 1
      out << "3"
    end
  end
  ```

  (minor [bd2f037b](https://github.com/appsignal/appsignal-ruby/commit/bd2f037ba4840f4606373ee2fc11553f098d5436))
- Add the `Appsignal.report_error` helper to report errors. If you unsure whether to use the `Appsignal.set_error` or `Appsignal.send_error` helpers in what context, use `Appsignal.report_error` to always report the error. (minor [1502ea14](https://github.com/appsignal/appsignal-ruby/commit/1502ea147210d77dd4ee9d301c52ace30c2a6700))
- Support nested webmachine apps. If webmachine apps are nested in other AppSignal instrumentation it will now report the webmachine instrumentation as part of the parent transaction, reporting more runtime of the request. (patch [243d20ac](https://github.com/appsignal/appsignal-ruby/commit/243d20acd68a9e59a01d74e17abb910691667b25))
- Report the response status for Padrino requests as the `response_status` tag on samples, e.g. 200, 301, 500. This tag is visible on the sample detail page.
  Report the response status for Padrino requests as the `response_status` metric.

  (patch [9239c26b](https://github.com/appsignal/appsignal-ruby/commit/9239c26beb144b9d8bf094bc58030cd618633c38))
- Add support for nested Padrino apps. When a Padrino app is nested in another Padrino app, or another framework like Sinatra or Rails, it will now report the entire request. (patch [9239c26b](https://github.com/appsignal/appsignal-ruby/commit/9239c26beb144b9d8bf094bc58030cd618633c38))
- Add `Appsignal.set_params` helper. Set custom parameters on the current transaction with the `Appsignal.set_params` helper. Note that this will overwrite any request parameters that would be set automatically on the transaction. When this method is called multiple times, it will overwrite the previously set value.

  ```ruby
  Appsignal.set_params("param1" => "value1", "param2" => "value2")
  ```

  (patch [e8d73e8d](https://github.com/appsignal/appsignal-ruby/commit/e8d73e8d31264c44dd5db5d769be6b599b0ded48))
- Add `Appsignal.set_custom_data` helper to set custom data on the transaction. Previously, this could only be set with `Appsignal::Transaction.current.set_custom_data("custom_data", ...)`. This helper makes setting the custom data more convenient. (patch [875e4435](https://github.com/appsignal/appsignal-ruby/commit/875e4435ba97838f79a02ff456d3418bc012634a))
- Add `Appsignal.set_tags` helper as an alias for `Appsignal.tag_request`. This is a context independent named alias available on the Transaction class as well. (patch [1502ea14](https://github.com/appsignal/appsignal-ruby/commit/1502ea147210d77dd4ee9d301c52ace30c2a6700))
- Add a block argument to the `Appsignal.set_params` and `Appsignal::Transaction#set_params` helpers. When `set_params` is called with a block argument, the block is executed when the parameters are stored on the Transaction. This block is only called when the Transaction is sampled. Use this block argument to avoid having to parse parameters for every transaction, to speed things up when the transaction is not sampled.

  ```ruby
  Appsignal.set_params do
    # Some slow code to parse parameters
    JSON.parse('{"param1": "value1"}')
  end
  ```

  (patch [1502ea14](https://github.com/appsignal/appsignal-ruby/commit/1502ea147210d77dd4ee9d301c52ace30c2a6700))

### Deprecated

- Deprecate the `appsignal.action` and `appsignal.route` request env methods to set the transaction action name. Use the `Appsignal.set_action` helper instead.

  ```ruby
  # Before
  env["appsignal.action"] = "POST /my-action"
  env["appsignal.route"] = "POST /my-action"

  # After
  Appsignal.set_action("POST /my-action")
  ```

  (patch [1e6d0b31](https://github.com/appsignal/appsignal-ruby/commit/1e6d0b315577176d4dd37db0a8f5fde89c66e8a4))
- Deprecate the `Appsignal::Rack::StreamingListener` middleware. Use the `Appsignal::Rack::InstrumentationMiddleware` middleware instead. (patch [57d6fa33](https://github.com/appsignal/appsignal-ruby/commit/57d6fa3386d9a9720da76c7b899a332952d472e0))
- Deprecate the `Appsignal::Rack::GenericInstrumentation` middleware. Use the `Appsignal::Rack::InstrumentationMiddleware` middleware instead. See also the changelog entry about the `InstrumentationMiddleware`. (patch [1502ea14](https://github.com/appsignal/appsignal-ruby/commit/1502ea147210d77dd4ee9d301c52ace30c2a6700))

### Fixed

- Fix issue with AppSignal getting stuck in a boot loop when loading the Padrino integration with: `require "appsignal/integrations/padrino"`
  This could happen in nested applications, like a Padrino app in a Rails app. AppSignal will now use the first config AppSignal starts with.

  (patch [10722b60](https://github.com/appsignal/appsignal-ruby/commit/10722b60d0ad9dc63b2c7add7d5ee8703190b8f0))
- Fix the deprecation warning of `Bundler.rubygems.all_specs` usage. (patch [1502ea14](https://github.com/appsignal/appsignal-ruby/commit/1502ea147210d77dd4ee9d301c52ace30c2a6700))

## 3.9.3

_Published on 2024-07-02._

### Added

- [0230ab4d](https://github.com/appsignal/appsignal-ruby/commit/0230ab4da00d75e4fc72fd493fc98441b5d7254d) patch - Track error response status for web requests. When an unhandled exception reaches the AppSignal EventHandler instrumentation, report the response status as `500` for the `response_status` tag on the transaction and on the `response_status` metric.

### Changed

- [b3a80038](https://github.com/appsignal/appsignal-ruby/commit/b3a800380c0d83422d7f3c0e9c93551d343c50c0) patch - Require the AppSignal gem in the Grape integration file. Previously `require "appsignal"` had to be called before `require "appsignal/integrations/grape"`. This `require "appsignal"` is no longer required.
- [e9aa0603](https://github.com/appsignal/appsignal-ruby/commit/e9aa06031b6c17f9f2704250bb1775a4cb72b276) patch - Report Global VM Lock metrics per process. In addition to the existing `hostname` tag, add `process_name` and `process_id` tags to the `gvl_global_timer` and `gvl_waiting_threads` metrics emitted by the [GVL probe](https://docs.appsignal.com/ruby/integrations/global-vm-lock.html), allowing these metrics to be tracked in a per-process basis.

### Deprecated

- [844aa0af](https://github.com/appsignal/appsignal-ruby/commit/844aa0afa3311860dca84badc27c2be8996bfd3c) patch - Deprecate `Appsignal::Grape::Middleware` constant in favor of `Appsignal::Rack::GrapeMiddleware` constant.
  
  To fix this deprecation warning, update the usage of `Appsignal::Grape::Middleware` like this:
  
  ```ruby
  # Grape only apps
  insert_before Grape::Middleware::Error, Appsignal::Rack::GrapeMiddleware
  # or
  use Appsignal::Rack::GrapeMiddleware
  
  # Grape on Rails app
  use Appsignal::Rack::GrapeMiddleware
  ```
- [1f648ab4](https://github.com/appsignal/appsignal-ruby/commit/1f648ab4d0372f37d15a980a9902779834811531) patch - Deprecate the `Appsignal.start_logger` method. Remove this method call from apps if it is present. Calling `Appsignal.start` will now initialize the logger.

### Fixed

- [0bb29809](https://github.com/appsignal/appsignal-ruby/commit/0bb29809f1750bdac2b66a1132a3638c58e6d1f8) patch - Fix an issue with invalid request methods raising an error in the GenericInstrumentation middleware when using a request class that throws an error when calling the `request_method` method, like `ActionDispatch::Request`.
- [66bb7a60](https://github.com/appsignal/appsignal-ruby/commit/66bb7a60cafd3fb1a91d4ed0430d51ee8ac8de46) patch - Support Grape apps that are nested in other apps like Sinatra and Rails, that also include AppSignal middleware for instrumentation.
- [a7b056bd](https://github.com/appsignal/appsignal-ruby/commit/a7b056bd333912b3b6388d68d6dd3af0b2cb9a75) patch - Support Hanami version 2.1. On older versions of our Ruby gem it would error on an unknown keyword argument "sessions_enabled".
- [00b7ac6a](https://github.com/appsignal/appsignal-ruby/commit/00b7ac6a9128d47fa9d3a1556f73a14304de8944) patch - Fix issue with AppSignal getting stuck in a boot loop when loading the Hanami integration with: `require "appsignal/integrations/hanami"`
  This could happen in nested applications, like a Hanami app in a Rails app. It will now use the first config AppSignal starts with.

## 3.9.2

_Published on 2024-06-26._

### Added

- Improve instrumentation of Hanami requests by making sure the transaction is always closed.
  It will also report a `response_status` tag and metric for Hanami requests.

  (patch [e79d4277](https://github.com/appsignal/appsignal-ruby/commit/e79d4277046bf4ec0d32263d06d4975ca8c426ee))

### Changed

- Instrument the entire Sinatra request. Instrumenting Sinatra apps using `require "appsignal/integrations/sinatra"` will now report more of the request, if previously other middleware were not instrumented. It will also report the response status with the `response_status` tag and metric. (patch [15b3390b](https://github.com/appsignal/appsignal-ruby/commit/15b3390b5b54cdc7378d69c92d91ec51dab1b0e4))

### Fixed

- Fix deprecation warnings about `Transacation.params=` usage by updating how we record parameters in our instrumentations. (patch [b65d6674](https://github.com/appsignal/appsignal-ruby/commit/b65d6674c93afbc95e9cecee8c032e6949229aab))
- Fix error reporting for requests with an error that use the AppSignal EventHandler. (patch [0e48f19b](https://github.com/appsignal/appsignal-ruby/commit/0e48f19bb9f5c3ead96d21fbacdd5d7f221e2063))

## 3.9.1

_Published on 2024-06-24._

### Fixed

- [0a253aa1](https://github.com/appsignal/appsignal-ruby/commit/0a253aa16c00cd6172e35a4edaff34f76ac9cbe5) patch - Fix parameter reporting for Rack and Sinatra apps, especially POST payloads.

## 3.9.0

_Published on 2024-06-21._

### Added

- [500b2b4b](https://github.com/appsignal/appsignal-ruby/commit/500b2b4bb57a29663a197ff063c672e6b0c44769) minor - Report Sidekiq errors when a job is dead/discarded. Configure the new `sidekiq_report_errors` config option to "discard" to only report errors when the job is not retried further.

### Changed

- [c76952ff](https://github.com/appsignal/appsignal-ruby/commit/c76952ff5c8bd6e9d1d841a3aeb600b27494bb43) patch - Improve instrumentation for mounted Sinatra apps in Rails apps. The sample reported for the Sinatra request will now include the time spent in Rails and its middleware.
- [661b8e08](https://github.com/appsignal/appsignal-ruby/commit/661b8e08de962e8f95326f0bbc9c0061b8cc0a62) patch - Support apps that have multiple Appsignal::Rack::EventHandler-s in the middleware stack.
- [7382afa3](https://github.com/appsignal/appsignal-ruby/commit/7382afa3e9c89ce0c9f3430fb71825736e484e82) patch - Improve support for instrumentation of nested pure Rack and Sinatra apps. It will now report more of the request's duration and events. This also improves support for apps that have multiple Rack GenericInstrumentation or SinatraInstrumentation middlewares.

### Fixed

- [2478eb19](https://github.com/appsignal/appsignal-ruby/commit/2478eb19f51c18433785347d02af18f405eeeabd) patch - Fix issue with AppSignal getting stuck in a boot loop when loading the Sinatra integration with: `require "appsignal/integrations/sinatra"`
  This could happen in nested applications, like a Sinatra app in a Rails app. It will now use the first config AppSignal starts with.

## 3.8.1

_Published on 2024-06-17._

### Added

- [5459a021](https://github.com/appsignal/appsignal-ruby/commit/5459a021d7d4bbbd09a0dcbdf5f3af7bf861b6f5) patch - Report the response status for Rails requests as the `response_status` tag on samples, e.g. 200, 301, 500. This tag is visible on the sample detail page.
  
  The response status is also reported as the `response_status` metric.

## 3.8.0

_Published on 2024-06-17._

### Changed

- [ca53b043](https://github.com/appsignal/appsignal-ruby/commit/ca53b04360ae123498640d043ee7ba74efc4b295) minor - Report the time spent in Rails middleware as part of the request duration. The AppSignal Rack middleware is now higher in the middleware stack and reports more time of the request to give insights in how long other middleware took. This is reported under the new `process_request.rack` event in the event timeline.

### Fixed

- [37fbae5a](https://github.com/appsignal/appsignal-ruby/commit/37fbae5a0f1a4e964baceb21837e5d5f0cf903c0) patch - Fix ArgumentError being raised on Ruby logger and Rails.logger error calls. This fixes the error from being raised from within the AppSignal Ruby gem.
  Please do not use this for error reporting. We recommend using our error reporting feature instead to be notified of new errors. Read more on [exception handling in Ruby with our Ruby gem](https://docs.appsignal.com/ruby/instrumentation/exception-handling.html).
  
  ```ruby
  # No longer raises an error
  Rails.logger.error StandardError.new("StandardError log message")
  ```

## 3.7.6

_Published on 2024-06-11._

### Changed

- [704a7d29](https://github.com/appsignal/appsignal-ruby/commit/704a7d29ae428f93549000a2c606bff948040c96) patch - When the minutely probes thread takes more than 60 seconds to run all the registered probes, log an error. This helps find issues with the metrics reported by the probes not being accurately reported for every minute.
- [5f4cc8be](https://github.com/appsignal/appsignal-ruby/commit/5f4cc8beb0ad88a0a58265d990626a7ee39fddd3) patch - Internal agent changes for the Ruby gem.

## 3.7.5

_Published on 2024-05-14._

### Added

- [bf81e165](https://github.com/appsignal/appsignal-ruby/commit/bf81e16593c7598e266d1e4cfb108aeef2ed7e73) patch - Support events emitted by ViewComponent. Rendering of ViewComponent-based components will appear as events in your performance samples' event timeline.
  
  For AppSignal to instrument ViewComponent events, you must first configure ViewComponent to emit those events:
  
  ```ruby
  # config/application.rb
  module MyRailsApp
    class Application < Rails::Application
      config.view_component.instrumentation_enabled = true
      config.view_component.use_deprecated_instrumentation_name = false
    end
  end
  ```
  
  Thanks to Trae Robrock (@trobrock) for providing a starting point for this implementation!
- [ad5c9955](https://github.com/appsignal/appsignal-ruby/commit/ad5c99556421fe86501205465053466a91f28448) patch - Support Kamal-based deployments. Read the `KAMAL_VERSION` environment variable, which Kamal exposes within the deployed container, if present, and use it as the application revision if it is not set. This will automatically report deploy markers for applications using Kamal.

### Fixed

- [30bb675f](https://github.com/appsignal/appsignal-ruby/commit/30bb675ffa99ec1949a613f309e6c1792b88d4ce) patch - Fix an issue where an error about the AppSignal internal logger is raised when sending a heartbeat.

## 3.7.4

_Published on 2024-05-09._

### Fixed

- [4f12684b](https://github.com/appsignal/appsignal-ruby/commit/4f12684baf6fadac43fcb5108f5a7f793b2e1046) patch - Fix LocalJumpError in Active Job instrumentation initialization for Active Job < 7.1.

## 3.7.3

_Published on 2024-05-08._

### Added

- [28a36ba1](https://github.com/appsignal/appsignal-ruby/commit/28a36ba17c236cf3f2f4991f3ff224a98c76eec7) patch - Add option to `activejob_report_errors` option to only report errors when a job is discard by Active Job. In the example below the job is retried twice. If it fails with an error twice the job is discarded. If `activejob_report_errors` is set to `discard`, you will only get an error reported when the job is discarded. This new `discard` value only works for Active Job 7.1 and newer.
  
  
  ```ruby
  class ExampleJob < ActiveJob::Base
    retry_on StandardError, :attempts => 2
  
    # ...
  end
  ```
- [d6d233de](https://github.com/appsignal/appsignal-ruby/commit/d6d233de8d1dd6aa203924e66db0635287aaea7b) patch - Track Active Job executions per job. When a job is retried the "executions" metadata for Active Job jobs goes up by one for every retry. We now track this as the `executions` tag on the job sample.

## 3.7.2

_Published on 2024-05-06._

### Fixed

- [b6e8ebe2](https://github.com/appsignal/appsignal-ruby/commit/b6e8ebe27e56d111337c5901e4b819bf97bba174) patch - Fix deprecation warnings for Probes.probes introduced in 3.7.1 for internally registered probes.

## 3.7.1

_Published on 2024-04-29._

### Changed

- [226a8f51](https://github.com/appsignal/appsignal-ruby/commit/226a8f51aa467f443ca8a93d4134f445b81f683a) patch - If the gem can't find a valid log path in the app's `log/` directory, it will no longer print the warning more than once.
- [5f97aa29](https://github.com/appsignal/appsignal-ruby/commit/5f97aa2997ca64955d6f7dc0a21de265eec110dc) patch - Stop the minutely probes when `Appsignal.stop` is called. When `Appsignal.stop` is called, the probes thread will no longer continue running in the app process.
- [ccfa3572](https://github.com/appsignal/appsignal-ruby/commit/ccfa3572260dc71765ff233682e50276059aa6aa) patch - Listen to the `APPSIGNAL_HTTP_PROXY` environment variable in the extension installer. When `APPSIGNAL_HTTP_PROXY` is set during `gem instal appsignal` or `bundle install`, it will use the proxy specified in the `APPSIGNAL_HTTP_PROXY` environment variable to download the extension and agent.
- [123c7108](https://github.com/appsignal/appsignal-ruby/commit/123c710861a09c4a857d749b3bf9e3b17968ce68) patch - Allow unregistering minutely probes. Use `Appsignal::Probes.unregister` to unregister probes registered with `Appsignal::Probes.register` if you do not need a certain probe, including default probes.
- [12305025](https://github.com/appsignal/appsignal-ruby/commit/1230502525004d324f3dbcf0ee61eb0e6fe7fdb5) patch - Add `Appsignal::Probes.register` method as the preferred method to register probes. The `Appsignal::Probes.probes.register` and `Appsignal::Minutely.probes.register` methods are now deprecated.
- [12305025](https://github.com/appsignal/appsignal-ruby/commit/1230502525004d324f3dbcf0ee61eb0e6fe7fdb5) patch - Automatically start new probes registered with `Appsignal::Probes.register` when the gem has already started the probes thread. Previously, the late registered probes would not be run.
- [12305025](https://github.com/appsignal/appsignal-ruby/commit/1230502525004d324f3dbcf0ee61eb0e6fe7fdb5) patch - Rename the Minutely constant to Probes so that the API is the same between AppSignal integrations. If your apps calls `Appsignal::Minutely`, please update it to `Appsignal::Probes`. If your app calls `Appsignal::Minutely` after this upgrade without the name change, the gem will print a deprecation warning for each time the `Appsignal::Minutely` is called.
- [ee08eed2](https://github.com/appsignal/appsignal-ruby/commit/ee08eed28a15955499bbb736fe76ae82a61de1b2) patch - Log debug messages when metrics are received for easier debugging.

### Fixed

- [a2f4b313](https://github.com/appsignal/appsignal-ruby/commit/a2f4b31359c13fc89bcf22e162cf9f79664edc6b) patch - Clear the AppSignal in memory logger, used during the gem start, after the file/STDOUT logger is started. This reduces memory usage of the AppSignal Ruby gem by a tiny bit, and prevent stale logs being logged whenever a process gets forked and starts AppSignal.

## 3.7.0

_Published on 2024-04-22._

### Added

- [5b0eb9b2](https://github.com/appsignal/appsignal-ruby/commit/5b0eb9b25ee3f5a738962acee9052dfce74acb29) minor - _Heartbeats are currently only available to beta testers. If you are interested in trying it out, [send an email to support@appsignal.com](mailto:support@appsignal.com?subject=Heartbeat%20beta)!_
  
  ---
  
  Add heartbeats support. You can send heartbeats directly from your code, to track the execution of certain processes:
  
  ```ruby
  def send_invoices()
    # ... your code here ...
    Appsignal.heartbeat("send_invoices")
  end
  ```
  
  You can pass a block to `Appsignal.heartbeat`, to report to AppSignal both when the process starts, and when it finishes, allowing you to see the duration of the process:
  
  ```ruby
  def send_invoices()
    Appsignal.heartbeat("send_invoices") do
      # ... your code here ...
    end
  end
  ```
  
  If an exception is raised within the block, the finish event will not be reported to AppSignal, triggering a notification about the missing heartbeat. The exception will bubble outside of the heartbeat block.
- [5fc83cc1](https://github.com/appsignal/appsignal-ruby/commit/5fc83cc186b1574d759731c5191edf13cf8339b7) patch - Implement the `ignore_logs` configuration option, which can also be configured as the `APPSIGNAL_IGNORE_LOGS` environment variable.
  
  The value of `ignore_logs` is a list (comma-separated, when using the environment variable) of log line messages that should be ignored. For example, the value `"start"` will cause any message containing the word "start" to be ignored. Any log line message containing a value in `ignore_logs` will not be reported to AppSignal.
  
  The values can use a small subset of regular expression syntax (specifically, `^`, `$` and `.*`) to narrow or expand the scope of lines that should be matched.
  
  For example, the value `"^start$"` can be used to ignore any message that is _exactly_ the word "start", but not messages that merely contain it, like "Process failed to start". The value `"Task .* succeeded"` can be used to ignore messages about task success regardless of the specific task name.

## 3.6.5

_Published on 2024-04-17._

### Fixed

- [83004ae5](https://github.com/appsignal/appsignal-ruby/commit/83004ae597e55a70673d6589c8b4457960d7b1ba) patch - Check the redis-client gem version before installing instrumentation. This prevents errors from being raised on redis-client gem versions older than 0.14.0.

## 3.6.4

_Published on 2024-03-25._

### Fixed

- [09b9aa41](https://github.com/appsignal/appsignal-ruby/commit/09b9aa41d374cd4ef5ca39c68721bd241e7c93a3) patch - Fix CPU `user`/`system` usage measurements, as to take into account the amount of CPUs available.

## 3.6.3

_Published on 2024-03-20._

### Added

- [e50433fb](https://github.com/appsignal/appsignal-ruby/commit/e50433fbcb109ef741a889b0b7e78f16b884bd81) patch - Implement CPU count configuration option. Use it to override the auto-detected, cgroups-provided number of CPUs that is used to calculate CPU usage percentages.
  
  To set it, use the the `cpu_count`
  configuration option or the `APPSIGNAL_CPU_COUNT` environment variable.

### Fixed

- [c6dd9779](https://github.com/appsignal/appsignal-ruby/commit/c6dd9779bb50dd9385da8962ccf1057ca1a44c7a) patch - Add request parameters, path and method tags to errors reported in controllers via the Rails error reporter.

## 3.6.2

_Published on 2024-03-08._

### Fixed

- [c3921865](https://github.com/appsignal/appsignal-ruby/commit/c392186573a72fd9afe22299fabcd14dcfe96139) patch - Revert Rack middleware changes (see [changelog](https://github.com/appsignal/appsignal-ruby/blob/main/CHANGELOG.md#360)) to fix issues relating to Unicorn broken pipe errors and multiple requests merging into a single sample.

## 3.6.1

_Published on 2024-03-05._

### Added

- [8974d201](https://github.com/appsignal/appsignal-ruby/commit/8974d20144407fce7a274ebaeb771ef76705d901) patch - Add `activejob_report_errors` config option. When set to `"none"`, ActiveJob jobs will no longer report errors. This can be used in combination with [custom exception reporting](https://docs.appsignal.com/ruby/instrumentation/exception-handling.html). By default, the config option has the value `"all"`, which reports all errors.

## 3.6.0

_Published on 2024-02-26._

### Added

- [9984156f](https://github.com/appsignal/appsignal-ruby/commit/9984156faea0a76cb0fe81594e1ddf40d55dabbe) minor - Add instrumentation for all Rack responses, including streaming responses. New `response_body_each.rack`, `response_body_call.rack` and `response_body_to_ary.rack` events will be shown in the event timeline. This will show how long it takes to complete responses, depending on the response implementation.
  
  This Sinatra route with a streaming response will be better instrumented, for example:
  
  ```ruby
  get "/stream" do
    stream do |out|
      sleep 1
      out << "1"
      sleep 1
      out << "2"
      sleep 1
      out << "3"
    end
  end
  ```
- [e7706038](https://github.com/appsignal/appsignal-ruby/commit/e7706038d8b2f52ea90441cfa62d5ee867d893a2) patch - Add histogram support to the OpenTelemetry HTTP server. This allows OpenTelemetry-based instrumentations to report histogram data to AppSignal as distribution metrics.

### Changed

- [11220302](https://github.com/appsignal/appsignal-ruby/commit/112203023a58e53e607a9fd7d545044fa7d896d5) minor - **Breaking change**: Normalize CPU metrics for cgroups v1 systems. When we can detect how many CPUs are configured in the container's limits, we will normalize the CPU percentages to a maximum of 100%. This is a breaking change. Triggers for CPU percentages that are configured for a CPU percentage higher than 100% will no longer trigger after this update. Please configure triggers to a percentage with a maximum of 100% CPU percentage.
- [11220302](https://github.com/appsignal/appsignal-ruby/commit/112203023a58e53e607a9fd7d545044fa7d896d5) patch - Support fractional CPUs for cgroups v2 metrics. Previously a CPU count of 0.5 would be interpreted as 1 CPU. Now it will be correctly seen as half a CPU and calculate CPU percentages accordingly.
- [14aefc35](https://github.com/appsignal/appsignal-ruby/commit/14aefc3594b3f55a4c2ab14ba1259a4f10499467) patch - Update bundled trusted root certificates.

### Fixed

- [f2abbd6a](https://github.com/appsignal/appsignal-ruby/commit/f2abbd6aeb2230d79139cbdf82af98557bbe5b54) patch - Fix (sub)traces not being reported in their entirety when the OpenTelemetry exporter sends one trace in multiple export requests. This would be an issue for long running traces, that are exported in several requests.

## 3.5.6

### Changed

- [c76a3293](https://github.com/appsignal/appsignal-ruby/commit/c76a329389c7ce55f1a8307d67fca6c0824c7b6f) patch - Default headers don't contain `REQUEST_URI` anymore as query params are not filtered. Now `REQUEST_PATH` is sent instead to avoid any PII filtering.

## 3.5.5

_Published on 2024-02-01._

### Added

- [d44f7092](https://github.com/appsignal/appsignal-ruby/commit/d44f7092a6a915ebe2825db7b0fe4e8e6eccd873) patch - Add support for the `redis-client` gem, which is used by the redis gem since version 5.

### Changed

- [6b9b814d](https://github.com/appsignal/appsignal-ruby/commit/6b9b814d958ca0a13f6da312746c11481bb46cfb) patch - Make the debug log message for OpenTelemetry spans from libraries we don't automatically recognize more clear. Mention the span id and the instrumentation library.
- [6b9b814d](https://github.com/appsignal/appsignal-ruby/commit/6b9b814d958ca0a13f6da312746c11481bb46cfb) patch - Fix an issue where queries containing a MySQL leading type indicator would only be partially sanitised.

### Fixed

- [e0f7b0e5](https://github.com/appsignal/appsignal-ruby/commit/e0f7b0e52eb5ed886d0f72941bd1c3c8fe15c9c0) patch - Add more testing to JRuby extension installation to better report the installation result and any possible failures.

## 3.5.4

### Changed

- [1a863490](https://github.com/appsignal/appsignal-ruby/commit/1a863490046318b8cee5fff2ac341fb73065f252) patch - Fix disk usage returning a Vec with no entries on Alpine Linux when the `df --local` command fails.

### Deprecated

- [bb98744b](https://github.com/appsignal/appsignal-ruby/commit/bb98744b1b6d34db71b5f46279b1a9b26039bd0f) patch - Deprecate the `Appsignal.set_host_gauge` and `Appsignal.set_process_gauge` helper methods in the Ruby gem. These methods would already log deprecation warnings in the `appsignal.log` file, but now also as a Ruby warning. These methods will be removed in the next major version. These methods already did not report any metrics, and still do not.

### Removed

- [1a863490](https://github.com/appsignal/appsignal-ruby/commit/1a863490046318b8cee5fff2ac341fb73065f252) patch - Remove the `appsignal_set_host_gauge` and `appsignal_set_process_gauge` extension functions. These functions were already deprecated and did not report any metrics.

### Fixed

- [0637b71d](https://github.com/appsignal/appsignal-ruby/commit/0637b71dedde155a2494c56f69bf3217e87e851d) patch - Fix the Makefile log path inclusion in the diagnose report. The diagnose tool didn't look in the correct gem extension directory for this log file.
- [fe71d78b](https://github.com/appsignal/appsignal-ruby/commit/fe71d78b2c897203bac5e6225bc1e21c6ba2c168) patch - Fix reporting of the Ruby syntax version and JRuby version in install report better.

## 3.5.3

### Changed

- [50708677](https://github.com/appsignal/appsignal-ruby/commit/50708677d3c1b3e630035f5b90458ecefa98e41c) patch - Log a warning when no mountpoints are found to report the disk usage metrics. This scenario shouldn't happen (it should log an error, message about skipping a mountpoint or log the disk usage). Log a warning to detect if this issue really occurs.

## 3.5.2

### Fixed

- [a5963f65](https://github.com/appsignal/appsignal-ruby/commit/a5963f65cd06cdc0f6482be34917c365affc87dd) patch - Fix Ruby Logger 1.6.0 compatibility

## 3.5.1

### Fixed

- [2e93182b](https://github.com/appsignal/appsignal-ruby/commit/2e93182b6ae83b16fe9885558cd8f0bfce6a9a5f) patch - Fix an error in the diagnose report when reading a file's contents results in an "Invalid seek" error. This could happen when the log path is configured to `/dev/stdout`, which is not supported.
- [ae0b779b](https://github.com/appsignal/appsignal-ruby/commit/ae0b779b3ec00cc46291bc0373d748d720231e74) patch - Fix logger compatibility with Ruby 3.3

## 3.5.0

### Added

- [cee1676f](https://github.com/appsignal/appsignal-ruby/commit/cee1676fc5539e380c58e8a824b5c59c3c927119) minor - Nested errors are now supported. The error causes are stored as sample data on the transaction so they can be displayed in the UI.

## 3.4.16

### Changed

- [2149c064](https://github.com/appsignal/appsignal-ruby/commit/2149c064be917d2784c4e5571fdfbd0c2ade59ca) patch - Filter more disk mountpoints for disk usage and disk IO stats. This helps reduce noise in the host metrics by focussing on more important mountpoints.
  
  The following mountpoint are ignored. Any mountpoint containing:
  
  - `/etc/hostname`
  - `/etc/hosts`
  - `/etc/resolv.conf`
  - `/snap/`
  - `/proc/`

### Fixed

- [2149c064](https://github.com/appsignal/appsignal-ruby/commit/2149c064be917d2784c4e5571fdfbd0c2ade59ca) patch - - Support disk usage reporting (using `df`) on Alpine Linux. This host metric would report an error on Alpine Linux.
  - When a disk mountpoint has no inodes usage percentage, skip the mountpoint, and report the inodes information successfully for the inodes that do have an inodes usage percentage.

## 3.4.15

### Changed

- [3fe0fa7a](https://github.com/appsignal/appsignal-ruby/commit/3fe0fa7a9cfbee0ca9f3e054155b236bd87c22fb) patch - Bump agent to eec7f7b
  
  Updated the probes dependency to 0.5.2. CPU usage is now normalized to the number of CPUs available to the container. This means that a container with 2 CPUs will have its CPU usage reported as 50% when using 1 CPU instead of 100%. This is a breaking change for anyone using the cpu probe.
  
  If you have CPU triggers set up based on the old behaviour, you might need to update those to these new normalized values to get the same behaviour. Note that this is needed only if the AppSignal integration package you're using includes this change.

## 3.4.14

### Changed

- [bd15ec20](https://github.com/appsignal/appsignal-ruby/commit/bd15ec204474efdc504973609b70074148032618) patch - Bump agent to e8207c1.
  
  - Add `memory_in_percentages` and `swap_in_percentages` host metrics that represents metrics in percentages.
  - Ignore `/snap/` disk mountpoints.
  - Fix issue with the open span count in logs being logged as a negative number.
  - Fix agent's TCP server getting stuck when two requests are made within the same fraction of a second.
- [09b45c80](https://github.com/appsignal/appsignal-ruby/commit/09b45c808c2d4b215bd38211860e8e89225886e6) patch - Bump agent to b604345.
  
  - Add an exponential backoff to the retry sleep time to bind to the StatsD, NGINX and OpenTelemetry exporter ports. This gives the agent a longer time to connect to the ports if they become available within a 4 minute window.
  - Changes to the agent logger:
    - Logs from the agent and extension now use a more consistent format in logs for spans and transactions.
    - Logs that are for more internal use are moved to the trace log level and logs that are useful for debugging most support issues are moved to the debug log level. It should not be necessary to use log level 'trace' as often anymore. The 'debug' log level should be enough.
  - Add `running_in_container` to agent diagnose report, to be used primarily by the Python package as a way to detect if an app's host is a container or not.
- [1945d613](https://github.com/appsignal/appsignal-ruby/commit/1945d61326266e225f13c6b828c51faf13c3745b) patch - Bump agent to 1dd2a18.
  
  - When adding an SQL body attribute via the extension, instead of truncating the body first and sanitising it later, sanitise it first and truncate it later. This prevents an issue where queries containing very big values result in truncated sanitisations.

### Fixed

- [c8698dca](https://github.com/appsignal/appsignal-ruby/commit/c8698dca465d84fdac33d88debc6fbb004458bf1) patch - Fix a deprecation warning for Sidekiq 7.1.6+ when an error is reported to AppSignal. (Thanks @bdewater-thatch!)
- [1c606c6a](https://github.com/appsignal/appsignal-ruby/commit/1c606c6a095ac9316cdb6fc26b98c72b9c23b583) patch - Fix an internal error when some Redis info keys we're expecting are missing. This will fix the Sidekiq dashboard showing much less data than we can report when Redis is configured to not report all the data points we expect. You'll still miss out of metrics like used memory, but miss less data than before.

## 3.4.13

### Added

- [29970d93](https://github.com/appsignal/appsignal-ruby/commit/29970d93a63aa174fbc4a41b29eff996ef0ede5e) patch - Events from `dry-monitor` are now supported. There's also native support for `rom-sql` instrumentation events if they're configured.
- [27656744](https://github.com/appsignal/appsignal-ruby/commit/27656744d5d5657d120b4fcd97857c17421d8dfd) patch - Support Rails 7.1 ActiveSupport Notifications handler.

### Changed

- [6932bb3f](https://github.com/appsignal/appsignal-ruby/commit/6932bb3f7eae75beeb86e29ddc16dc16f9da4428) patch - Add configuration load modifiers to diagnose report. Track if the `APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR` environment variable was set.

## 3.4.12

### Added

- [441de353](https://github.com/appsignal/appsignal-ruby/commit/441de3537e7a8f36dd2460149c171aaa80929e53) patch - Add an option to not start AppSignal on config file errors. When the `config/appsignal.yml` file raises an error (due to ERB syntax issues or ERB errors), it will currently ignore the config file and try to make a configuration work from the other config sources (default, auto detection and system environment variables). This can cause unexpected behavior, because the config from the config file is not part of the loaded config.
  
  In future versions of the Ruby gem, AppSignal will not start when the config file contains an error. To opt-in to this new behavior, set the `APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR` system environment variable to either `1` or `true`.

### Changed

- [a42da92b](https://github.com/appsignal/appsignal-ruby/commit/a42da92b1ff16c48eb40dc081d3b4fbd6480c7c0) patch - Log an error when sample data is of an invalid type. Accepted types are Array and Hash. If any other types are given, it will log an error to the `appsignal.log` file.

### Fixed

- [8e636323](https://github.com/appsignal/appsignal-ruby/commit/8e6363232dc7fabe5f1aeae5758802e4c8d6cbfa) patch - Bump agent to 6133900.
  
  - Fix `disk_inode_usage` metric name format to not be interpreted as a JSON object.

## 3.4.11

### Added

- [4722292d](https://github.com/appsignal/appsignal-ruby/commit/4722292d022fb7ff7f3403b964b24e82112e93bd) patch - Re-add support for Ruby 2.7.
- [d782f9a6](https://github.com/appsignal/appsignal-ruby/commit/d782f9a6db0bd679f01c543900b39fc15124a25f) patch - Add the `host_role` config option. This config option can be set per host to generate some metrics automatically per host and possibly do things like grouping in the future.

### Changed

- [f61f4f68](https://github.com/appsignal/appsignal-ruby/commit/f61f4f68699f022d3d9dbb0fa5dc98881923a001) patch - Bump agent to version d789895.
  
  - Increase short data truncation from 2000 to 10000 characters.

## 3.4.10

### Changed

- [61e093b8](https://github.com/appsignal/appsignal-ruby/commit/61e093b8b89efd9914fe5252b6200a288348d394) patch - Bump agent to 6bec691.
  
  - Upgrade `sql_lexer` to v0.9.5. It adds sanitization support for the `THEN` and `ELSE` logical operators.

## 3.4.9

### Added

- [d048c778](https://github.com/appsignal/appsignal-ruby/commit/d048c778e2718110609ba03f4d755953828bf4c5) patch - Allow passing custom data using the `appsignal` context via the Rails error reporter:
  
  ```ruby
  custom_data = { :hash => { :one => 1, :two => 2 }, :array => [1, 2] }
  Rails.error.handle(:context => { :appsignal => { :custom_data => custom_data } }) do
    raise "Test"
  end
  ```

## 3.4.8

### Added

- [5ddde58b](https://github.com/appsignal/appsignal-ruby/commit/5ddde58bb492984626d2dbddb292cecdfc225576) patch - Allow configuration of the agent's TCP and UDP servers using the `bind_address` config option. This is by default set to `127.0.0.1`, which only makes it accessible from the same host. If you want it to be accessible from other machines, use `0.0.0.0` or a specific IP address.
- [74583d26](https://github.com/appsignal/appsignal-ruby/commit/74583d26147e3ec386cdefbd4653abbe805ded96) patch - Report total CPU usage host metric for VMs. This change adds another `state` tag value on the `cpu` metric called `total_usage`, which reports the VM's total CPU usage in percentages.

## 3.4.7

### Added

- [46735abb](https://github.com/appsignal/appsignal-ruby/commit/46735abb0d0c43df2c923b36f80549b8322ae4f6) patch - Use `RENDER_GIT_COMMIT` environment variable as revision if no revision is specified.

### Changed

- [86856aae](https://github.com/appsignal/appsignal-ruby/commit/86856aae7c16dc13854229d43c7369ec69ced18e) patch - Bump agent to 32590eb.
  
  - Only ignore disk metrics that start with "loop", not all mounted disks that end with a number to report metrics for more disks.

## 3.4.6

### Changed

- [85c155a0](https://github.com/appsignal/appsignal-ruby/commit/85c155a0a4b2b618c04db52c34ee7f0adba8f3c5) patch - When sanitizing an array or hash, replace recursively nested values with a placeholder string. This fixes a SystemStackError issue when sanitising arrays and hashes.

## 3.4.5

### Added

- [e5e79d9a](https://github.com/appsignal/appsignal-ruby/commit/e5e79d9aa17006a6995e9ea18fabdc14a2356c82) patch - Add `filter_metadata` config option to filter metadata set on Transactions set by default. Metadata like `path`, (request)  `method`, `request_id`, `hostname`, etc. This can be useful if there's PII or other sensitive data in any of the app's metadata.

### Fixed

- [5a4797c8](https://github.com/appsignal/appsignal-ruby/commit/5a4797c8560c2d1e60b4f1a750136c906505746c) patch - Fix Sinatra request custom request parameters method. If the Sinatra option `params_method` is set, a different method than `params` will be called on the request object to fetch the request parameters. This can be used to add custom filtering to parameters recorded by AppSignal.
- [9cdee8aa](https://github.com/appsignal/appsignal-ruby/commit/9cdee8aae3cb7b969583493440469ac0dfea764f) patch - Log error when the argument type of the breadcrumb metadata is invalid. This metadata argument should be a Hash, and other values are not supported. More information can be found in the [Ruby gem breadcrumb documentation](https://docs.appsignal.com/ruby/instrumentation/breadcrumbs.html).
  
  ```ruby
  Appsignal.add_breadcrumb(
    "breadcrumb category",
    "breadcrumb action",
    "some message",
    { :metadata_key => "some value" } # This needs to be a Hash object
  )
  ```

## 3.4.4

### Fixed

- [17500724](https://github.com/appsignal/appsignal-ruby/commit/175007245a5506cf06e5447acad431014b461fff) patch - Fixed a bug that prevented log messages from getting to AppSignal when using the convenience methods as in:
  
  ```ruby
  Rails.logger.warn("Warning message")
  ```

## 3.4.3

### Added

- [8e54a894](https://github.com/appsignal/appsignal-ruby/commit/8e54a8948b815a701277a5da7baf303656548d62) patch - Allow configuration of the agent's StatsD server port through the `statsd_port` option.

### Changed

- [b9a8effe](https://github.com/appsignal/appsignal-ruby/commit/b9a8effeb43644981fc32d6a69757aa4e816a0b0) patch - Update bundled trusted root certificates.
- [d03735c7](https://github.com/appsignal/appsignal-ruby/commit/d03735c7b047d4e27e46dad0d61800ea20a3482f) patch - Bump agent to fd8ee9e.
  
  - Rely on APPSIGNAL_RUNNING_IN_CONTAINER config option value before other environment factors to determine if the app is running in a container.
  - Fix container detection for hosts running Docker itself.
  - Add APPSIGNAL_STATSD_PORT config option.

## 3.4.2

### Changed

- [645d749f](https://github.com/appsignal/appsignal-ruby/commit/645d749f67c2ead37e44b435a0525e7334d660a2) patch - Update agent to version 6f29190.
  
  - Log revision config in boot debug log.
  - Update internal agent CLI start command.
  - Rename internal `_APPSIGNAL_ENVIRONMENT` variable to `_APPSIGNAL_APP_ENV` to be consistent with the public version.

### Fixed

- [4cd1601e](https://github.com/appsignal/appsignal-ruby/commit/4cd1601ecb9ed417c14eaea964a8efa35bbb9f76) patch - Do not run minutely probes on Rails console

## 3.4.1

### Added

- [77ce4e39](https://github.com/appsignal/appsignal-ruby/commit/77ce4e3997fc7525d71f705cb332c05765568dc6) patch - Add Rails [error reporter](https://guides.rubyonrails.org/error_reporting.html) support. Errors reported using `Rails.error.handle` are tracked as separate errors in AppSignal. We rely on our other Rails instrumentation to report the errors reported with `Rails.error.record`.
  
  The error is reported under the same controller/job name, on a best effort basis. It may not be 100% accurate. If `Rails.error.handle` is called within a Rails controller or Active Job job, it will copy the AppSignal transaction namespace, action name and tags from the current transaction to the transaction for the `Rails.error.handle` reported error. If you call `Appsignal.set_namespace`, `Appsignal.set_action` or `Appsignal.tag_request` after `Rails.error.handle`, those changes will not be reflected up in the already reported error.
  
  It is also possible to customize the AppSignal namespace and action name for the reported error using the `appsignal` context:
  
  ```ruby
  Rails.error.handle(:context => { :appsignal => { :namespace => "context", :action => "ContextAction" } }) do
    raise "Test"
  end
  ```
  
  All other key-values are reported as tags:
  
  ```ruby
  Rails.error.handle(:context => { :tag_key => "tag value" }) do
    raise "Test"
  end
  ```
  
  Integration with the Rails error reporter is enabled by default. Disable this feature by setting the `enable_rails_error_reporter` config option to `false`.
- [b4f58afd](https://github.com/appsignal/appsignal-ruby/commit/b4f58afdeb80cd1eb336ec5bd7b5daf46a4ef0a8) patch - Support Sidekiq in Rails error reporter. Track errors reported using `Rails.error.handle` in Sidekiq jobs, in the correct action. Previously it would report no action name for the incident, now it will use the worker name by default.

### Changed

- [e0332791](https://github.com/appsignal/appsignal-ruby/commit/e03327913fdc19db68fc953308eb1e4f2441ba05) patch - Set the AppSignal transaction namespace, action name and some tags, before Active Job jobs are performed. This allows us to check what the namespace, action name and some tags are during the instrumentation itself.
- [4a40699a](https://github.com/appsignal/appsignal-ruby/commit/4a40699a1655bc10b3fa6eb90135374a6b31b195) patch - The AppSignal gem requires Ruby 3 or higher to run. Remove unnecessary Ruby version checks that query Ruby 2.7 or lower.
- [da7d1c76](https://github.com/appsignal/appsignal-ruby/commit/da7d1c762fa097080b884bccf7c083aa692803bc) patch - Internal refactor of Ruby code due to RuboCop upgrade. Use the public `prepend` method to prepend AppSignal instrumentation modules.

### Fixed

- [009d533f](https://github.com/appsignal/appsignal-ruby/commit/009d533f92b08663eca1460b990524d56322fb65) patch - Fix a bug when using ActiveSupport::TaggedLogging calling the `silence` method.

## 3.4.0

### Deprecated

- [6f9b7a4d](https://github.com/appsignal/appsignal-ruby/commit/6f9b7a4d12c6ff3353359cb37c5c02af8bbc6ec6) minor - Remove support for Ruby versions in that are end of life, following our [maintenance policy](https://docs.appsignal.com/support/maintenance-policy.html). Please upgrade your Ruby version to a supported version before upgrading AppSignal.

### Fixed

- [5b7735ac](https://github.com/appsignal/appsignal-ruby/commit/5b7735ac5868b0fbf9727922a32ca4645d4e2fdd) patch - Fix Logger add method signature error

## 3.3.10

### Fixed

- [48389475](https://github.com/appsignal/appsignal-ruby/commit/48389475f7739f5688e0251902227404e5f93b96) patch - The `Appsignal::Logger` is now compatible with `ActiveSupport::Logger.broadcast`.

## 3.3.9

### Fixed

- [a6db61b9](https://github.com/appsignal/appsignal-ruby/commit/a6db61b9a14a5a3b4ba89c99d35229bcdee98f94) patch - Fixed an error when using our Logging feature with Ruby's default logger formatter.

## 3.3.8

### Added

- [2fc6ba85](https://github.com/appsignal/appsignal-ruby/commit/2fc6ba85be1e0cabc2bb8fb26469ad47d1c60243) patch - Support "warning" value for `log_level` config option. This option was documented, but wasn't accepted and fell back on the "info" log level if used. Now it works to configure it to the "warn"/"warning" log level.
- [c04f7783](https://github.com/appsignal/appsignal-ruby/commit/c04f778332048aeaad9f75c131247caa29e504fa) patch - Add global VM lock metrics. If the `gvltools` library is installed, AppSignal for Ruby will report metrics on the global VM lock and the number of waiting threads in your application.

## 3.3.7

### Added

- [a815b298](https://github.com/appsignal/appsignal-ruby/commit/a815b29826a84f430384e7e735f79c8c312f1abf) patch - Support cgroups v2. Used by newer Docker engines to report host metrics. Upgrade if you receive no host metrics for Docker containers.

### Changed

- [8e67159e](https://github.com/appsignal/appsignal-ruby/commit/8e67159e2a57d3b697a07fadd8eb0e0234db9124) patch - Configure AppSignal with the RACK_ENV or RAILS_ENV environment variable in diagnose CLI, if present. Makes it easier to run the diagnose CLI in production, without having to always specify the environment with the `--environment` CLI option.
- [a815b298](https://github.com/appsignal/appsignal-ruby/commit/a815b29826a84f430384e7e735f79c8c312f1abf) patch - Allow transaction events to have a duration up to 48 hours before being discarded.

### Fixed

- [a815b298](https://github.com/appsignal/appsignal-ruby/commit/a815b29826a84f430384e7e735f79c8c312f1abf) patch - Remove trailing comments in SQL queries, ensuring queries are grouped consistently.
- [a815b298](https://github.com/appsignal/appsignal-ruby/commit/a815b29826a84f430384e7e735f79c8c312f1abf) patch - Fix an issue where events longer than forty-eight minutes would be shown as having a zero-second duration.

## 3.3.6

### Changed

- [962d069c](https://github.com/appsignal/appsignal-ruby/commit/962d069ce46fd7bf404a2ce28343e1f650ce3b37) patch - Bump agent to 8d042e2.
  
  - Support multiple log formats.

## 3.3.5

### Changed

- [fc85adde](https://github.com/appsignal/appsignal-ruby/commit/fc85adde11d7a35b1ca64c0f0714c6fcdd570590) patch - Bump agent to 0d593d5.
  
  - Report shared memory metric state.

## 3.3.4

### Added

- [75e29895](https://github.com/appsignal/appsignal-ruby/commit/75e298951d4955871585194c6940992c3e081864) patch - Add NGINX metrics support. See [our documentation](https://docs.appsignal.com/metrics/nginx.html) for details.

## 3.3.3

### Fixed

- [b2f872bc](https://github.com/appsignal/appsignal-ruby/commit/b2f872bc599f45378639cc9465e64c5c4730ab79) patch - Fix the T_DATA warning originating from the AppSignal C extension on Ruby 3.2.

## 3.3.2

### Changed

- [d1b960f0](https://github.com/appsignal/appsignal-ruby/commit/d1b960f0350b55962621d740e6a92922b334ab49) patch - Reduce our dependency on YAML during installation. Instead of a YAML file with details about the extension download location, use a pure Ruby file. This is a partial fix for the installation issue involving psych version 5.

### Fixed

- [e1e598ae](https://github.com/appsignal/appsignal-ruby/commit/e1e598ae51512a51486446e5751e504d4fc90ef0) patch - Skip the `.gemrc` config during installation if it raises an error loading it. This can be caused when the psych gem version 5 is installed on Ruby < 3.2. Use the `HTTP_PROXY` environment variable instead to configure the HTTP proxy that should be used during installation.

## 3.3.1

### Added

- [7f62ada8](https://github.com/appsignal/appsignal-ruby/commit/7f62ada8deb67a2b7d355ec0c1bc2ad1d1e2d8d1) patch - Track the Operating System release/distro in the diagnose report. This helps us with debugging what exact version of Linux an app is running on, for example.

### Fixed

- [1443e05f](https://github.com/appsignal/appsignal-ruby/commit/1443e05f0fa5bf6af69c40753b2d135f082871de) patch - Attempt to load C extension from lib/ directory. Fixes an issue where JRuby would fail to load
  the extension from the ext/ directory, as the directory is cleaned after installation when using
  RubyGems 3.4.0.

## 3.3.0

### Added

- [e4314b5b](https://github.com/appsignal/appsignal-ruby/commit/e4314b5b2d3fdf7865555535b2324094ec620349) minor - Hanami 2 is now supported. Requests will now appear as performance measurements.

## 3.2.2

### Changed

- [2b1964d9](https://github.com/appsignal/appsignal-ruby/commit/2b1964d94eee0b20c12f5c602c427643057e787b) patch - Track new Ruby 3.2 VM cache metrics. In Ruby 3.2 the `class_serial` and `global_constant_state` metrics are no longer reported for the "Ruby (VM) metrics" magic dashboard, because Ruby 3.2 removed these metrics. Instead we will now report the new `constant_cache_invalidations` and `constant_cache_misses` metrics reported by Ruby 3.2.
- [6804e898](https://github.com/appsignal/appsignal-ruby/commit/6804e89817234c88105d2376687b5574bfc8e8c9) patch - Use log formatter if set in logger

## 3.2.1

### Fixed

- [5e87aa34](https://github.com/appsignal/appsignal-ruby/commit/5e87aa34878d84cd07717671e770a0a356ad8430) patch - Support the http.rb gem's URI argument using objects with the `#to_s` method. A Ruby URI object is no longer required.

## 3.2.0

### Added

- [199d05c0](https://github.com/appsignal/appsignal-ruby/commit/199d05c0f95be7f2496ddcd05613eb816e9ad4e4) minor - Support the http.rb gem. Any outgoing requests will be tracked as events on the incident event timeline. This instrumentation is activated automatically, but can be disable by setting the `instrumentation_http_rb` option to `false`.
- [9bcd107d](https://github.com/appsignal/appsignal-ruby/commit/9bcd107de955e557744434fc9f953588a9c7bc49) minor - Support log collection from Ruby apps using the new AppSignal Logging feature. Learn more about [AppSignal's Logging on our docs](https://docs.appsignal.com/logging/platforms/integrations/ruby.html).

## 3.1.6

### Fixed

- [a03b7246](https://github.com/appsignal/appsignal-ruby/commit/a03b72461f5f3b047ca81368cf2bdbeadf078e08) patch - Support Sidekiq 7 in the Sidekiq minutely probe. It will now report metrics to Sidekiq magic dashboard for Sidekiq version 7 and newer.

## 3.1.5

### Changed

- [4035c3c2](https://github.com/appsignal/appsignal-ruby/commit/4035c3c2d5c0b002119054014daddd193bd820f0) patch - Bump agent to version 813a59b
  
  - Fix http proxy config option parsing for port 80.
  - Fix the return value for appsignal_import_opentelemetry_span extension
    function in `appsignal.h`.

### Fixed

- [feb60fb8](https://github.com/appsignal/appsignal-ruby/commit/feb60fb877a2b264e587fe3d5d546e40d86c9c38) patch - Fix NoMethodError for AppSignal Puma plugin for Puma 6. Puma 5 is also still supported.

## 3.1.4

### Added

- [ffe49cfe](https://github.com/appsignal/appsignal-ruby/commit/ffe49cfe94f5269e59d6f168a73114f7a3914f79) patch - Support temporarily disabling GC profiling without reporting inaccurate `gc_time` metric durations. The MRI probe's `gc_time` will not report any value when the `GC::Profiler.enabled?` returns `false`.

### Changed

- [af7e666c](https://github.com/appsignal/appsignal-ruby/commit/af7e666cf173ec1f42e9cf3fce2ab6c8e658440c) patch - Listen if the Ruby Garbage Collection profiler is enabled and collect how long the GC is running for the Ruby VM magic dashboard. An app will need to call `GC::Profiler.enable` to enable the GC profiler. Do not enable this in production environments, or at least not for long, because this can negatively impact performance of apps.

### Fixed

- [b3a163be](https://github.com/appsignal/appsignal-ruby/commit/b3a163be154796e1f358c5061eaee99845c960ee) patch - Fix the MRI probe using the Garbage Collection profiler instead of the NilProfiler when garbage collection instrumentation is not enabled for MRI probe. This caused unnecessary overhead.

## 3.1.3

### Added

- [811a1082](https://github.com/appsignal/appsignal-ruby/commit/811a10825043ed584f23d870e3a420ee409eb151) patch - Add the `Transaction.current?` helper to determine if any Transaction is currently active or not. AppSignal `NilTransaction`s are not considered active transactions.

### Changed

- [dc50d889](https://github.com/appsignal/appsignal-ruby/commit/dc50d8892699bf17b2399865ead8b27ce45b60ed) patch - Rename the (so far privately reported) `gc_total_time` metric to `gc_time`. It no longer reports the total time of Garbage Collection measured, but only the time between two (minutely) measurements.

### Fixed

- [7cfed987](https://github.com/appsignal/appsignal-ruby/commit/7cfed98761cf81d475261c553486b24843460cf3) patch - Fix error on unknown HTTP request method. When a request is made with an unknown request method, triggering and `ActionController::UnknownHttpMethod`, it will no longer break the AppSignal instrumentation but omit the request method in the sample data.

## 3.1.2

### Changed

- [1b95bb4c](https://github.com/appsignal/appsignal-ruby/commit/1b95bb4c8df08128cfa2db0d918ffcb909e5ee4c) patch - Report Garbage Collection total time metric as the delta between measurements. This reports a more user friendly metric that doesn't always goes up until the app restarts or gets a new deploy. This metric is reported 0 by default without `GC::Profiler.enable` having been called.
- [61a78fb0](https://github.com/appsignal/appsignal-ruby/commit/61a78fb028b04ae6f0a4ca1fc469d744f23c5029) patch - Bump agent to 06391fb
  
  - Accept "warning" value for the `log_level` config option.
  - Add aarch64 Linux musl build.
  - Improve debug logging from the extension.
  - Fix high CPU issue for appsignal-agent when nothing could be read from the socket.

## 3.1.1

### Changed

- [e225c798](https://github.com/appsignal/appsignal-ruby/commit/e225c798c65aef6085bb689597b7f3359fe138f7) patch - Report all Ruby VM metrics as gauges. We previously reported some metrics as distributions, but all fields for those distributions would report the same values.

### Fixed

- [31fd19c6](https://github.com/appsignal/appsignal-ruby/commit/31fd19c6019db2c68b359f1fc4ed3d5e4843e349) patch - Add hostname tag for Ruby VM metrics. This allows us to graph every host separately and multiple hosts won't overwrite each other metrics.

## 3.1.0

### Added

- [d10c3f32](https://github.com/appsignal/appsignal-ruby/commit/d10c3f32facbf399d7afe1d2ddbb5764fb57b008) minor - Add tracking of thread counts, garbage collection runs, heap slots and other garbage collection stats to the default MRI probe. These metrics will be shown in AppSignal.com in a new Ruby VM Magic Dashboard.

### Changed

- [114fe4f9](https://github.com/appsignal/appsignal-ruby/commit/114fe4f92e621bc2e771bb0fb608b5c6189f2933) patch - Bump agent to v-d573c9b
  
  - Display unsupported OpenTelemetry spans in limited form.
  - Clean up payload storage before sending. Should fix issues with locally queued payloads blocking data from being sent.
  - Add `appsignal_create_opentelemetry_span` function to create spans for further modification, rather than only import them.
- [dd803449](https://github.com/appsignal/appsignal-ruby/commit/dd803449bd3990ba020c0bec4429166977071c02) patch - Report gauge delta value for allocated objects. This reports a more user friendly metric we can graph with a more stable continuous value in apps with stable memory allocation.
- [547f925e](https://github.com/appsignal/appsignal-ruby/commit/547f925e392bb9f4f10ba95f371e42ddfe0de5de) patch - Report gauge delta value for Garbage Collection counts. This reports a more user friendly metric that doesn't always goes up until the app restarts or gets a new deploy.

### Fixed

- [e555a81a](https://github.com/appsignal/appsignal-ruby/commit/e555a81ab65cc951383f54d0e9a6c57d8cc2ac51) patch - Fix FFI function calls missing arguments for `appsignal_free_transaction` and `appsignal_free_data` extension functions. This fixes a high CPU issue when these function calls would be retried indefinitely.

## 3.0.27

### Fixed

- [7032dc4b](https://github.com/appsignal/appsignal-ruby/commit/7032dc4b45c150c58a7a97c44b17e1092934c1ec) patch - Use `Dir.pwd` to determine the current directory in the Capistrano 3 integration. It previously relied on `ENV["pwd"]` which returned `nil` in some scenarios.

## 3.0.26

### Removed

- [56ec42ae](https://github.com/appsignal/appsignal-ruby/commit/56ec42ae634c5675b1769963688a8f3f22715e0e) patch - Remove Moped support as it is no longer the official Ruby Mongo driver and it's been unmaintained for 7 years.

### Fixed

- [991ca18d](https://github.com/appsignal/appsignal-ruby/commit/991ca18dfc5b05cf34841f84c17d821a17bf7a84) patch - Fix runtime errors on YAML load with older psych versions (`< 4`) used in combination with newer Ruby version (`3.x`).

## 3.0.25

### Added

- [399cf790](https://github.com/appsignal/appsignal-ruby/commit/399cf79044e7c8936ab72dce420d91af4cb71d16) patch - Sanitize `ActiveRecord::RecordNotUnique` error messages to not include any database values that is not unique in the database. This ensures no personal information is sent to AppSignal through error messages from this error.

## 3.0.24

### Changed

- [964861f7](https://github.com/appsignal/appsignal-ruby/commit/964861f76ea7ff71f01497f116def14190bcd404) patch - Bump agent to v-f57e6cb
  
  - Enable process metrics on Heroku and Dokku

## 3.0.23

### Fixed

- [d73905d3](https://github.com/appsignal/appsignal-ruby/commit/d73905d3b28404638a8aa1e8de3909eff0b8cfb6) patch - Fix sanitized values wrapped in Arrays. When a value like `[{ "foo" => "bar" }]` was sanitized it would be stored as `{ "foo" => "?" }`, omitting the parent value's Array square brackets. Now values will appear with the same structure as they were originally sanitized. This only applies to certain integrations like MongoDB, moped and ElasticSearch.
- [096d3cdf](https://github.com/appsignal/appsignal-ruby/commit/096d3cdfd8f452f13b2dbf7de6b763c8a96973b3) patch - Fix the ActiveJob `default_queue_name` config option issue being reset to "default". When ActiveJob `default_queue_name` was set in a Rails initializer it would reset on load to `default`. Now the `default_queue_name` can be set in an initializer as well.

## 3.0.22

### Changed

- [9762e79d](https://github.com/appsignal/appsignal-ruby/commit/9762e79d4545e50c8f3540deff825b10d77e59a5) patch - Bump agent to v-bbc830a
  
  - Support batched statsd messages
  - Set start times for spans with traceparents
  - Check duration in transactions for negative and too high value

## 3.0.21

### Changed

- [548dd6f4](https://github.com/appsignal/appsignal-ruby/commit/548dd6f4c61ae3be24995a200dc3e5bea1a5f58c) patch - Add config override source. Track final decisions made by the Ruby gem in the configuration in the `override` config source. This will help us track new config options which are being set by their deprecated predecessors in the diagnose report.

### Removed

- [3f503ade](https://github.com/appsignal/appsignal-ruby/commit/3f503ade83f22f4b0d86d76ea00e5f4dd3c56b6f) patch - Remove internal `Appsignal.extensions` system. It was unused.

## 3.0.21.alpha.1

### Changed

- [f19d9dcc](https://github.com/appsignal/appsignal-ruby/commit/f19d9dcc1c00103f5dc92951481becf4d4ade39e) patch - The MongoDB query sanitization now shows all the attributes in the query at all levels.
  Only the actual values are filtered with a `?` character. Less MongoDB queries are now marked
  as N+1 queries when they weren't the exact same query. This increases the number of unique events
  AppSignal tracks for MongoDB queries.

## 3.0.20

### Added

- [35bd83b8](https://github.com/appsignal/appsignal-ruby/commit/35bd83b84fd30f0188d9f134cfd249360b6e281d) patch - Add `send_session_data` option to configure if session data is automatically included transactions. By default this is turned on. It can be disabled by configuring `send_session_data` to `false`.

### Deprecated

- [35bd83b8](https://github.com/appsignal/appsignal-ruby/commit/35bd83b84fd30f0188d9f134cfd249360b6e281d) patch - Deprecate `skip_session_data` option in favor of the newly introduced `send_session_data` option. If it is configured it will print a warning on AppSignal load, but will also retain its functionality until the config option is fully removed in the next major release.
- [e51a8fb6](https://github.com/appsignal/appsignal-ruby/commit/e51a8fb653fccc5a6b72ac7af9c9417e6827e2e9) patch - Warn about the deprecated `working_dir_path` option from all config sources. It previously only printed a warning when it was configured in the `config/appsignal.yml` file, but now also prints the warning if it's set via the Config class initialize options and environment variables. Please use the `working_directory_path` option instead.

### Fixed

- [c9000eee](https://github.com/appsignal/appsignal-ruby/commit/c9000eeefec722cb940b2e14f37d31a7827986d6) patch - Fix reported Ruby version in diagnose report. It would report only the first major release of the series, e.g. 2.6.0 for 2.6.1.

## 3.0.19

### Changed

- [2587eae3](https://github.com/appsignal/appsignal-ruby/commit/2587eae30f17e0f0b5e27cb61982301220cc77b1) patch - Store the extension install report as JSON, instead of YAML. Reduces internal complexity.

### Fixed

- [243c1ed4](https://github.com/appsignal/appsignal-ruby/commit/243c1ed444f3351ca158200a47836673f851cb31) patch - Improve compatibility with the sequel-rails gem by tracking the performed SQL query in instrumentation events.

## 3.0.18

### Added

- [d7bfcdf1](https://github.com/appsignal/appsignal-ruby/commit/d7bfcdf11a66df1ec5f54ac9342e5566062013b5) patch - Add Ruby 3.1.0 support. There was an issue with `YAML.load` arguments when parsing the `appsignal.yml` config file.

## 3.0.17

### Fixed

- [f9d57752](https://github.com/appsignal/appsignal-ruby/commit/f9d5775217400c59a70d98e9aa96e3dcd06cb1f9) patch - Use the `log_level` option for the Ruby gem logger. Previously it only configured the extension and agent loggers. Also fixes the `debug` and `transaction_debug_mode` option if no `log_level` is configured by the app.

## 3.0.16

### Added

- [fe226e99](https://github.com/appsignal/appsignal-ruby/commit/fe226e99f262bfa46e7a7630defe2fe90f8a3a13) patch - Add experimental Span API. This is not loaded by default and we do not recommend using it yet.
- [84b1ba18](https://github.com/appsignal/appsignal-ruby/commit/84b1ba18e50440e5c71d27319e560c5df180d0df) patch - Add "log_level" config option. This new option allows you to define the kind of messages
  AppSignal's will log and up. The "debug" option will log all "debug", "info", "warning" and
  "error" log messages. The default value is: "info"
  
  The allowed values are:
  - error
  - warning
  - info
  - debug
- [6b2ecca2](https://github.com/appsignal/appsignal-ruby/commit/6b2ecca24603061f1b35800f60b0ee6e9f314998) patch - Clean up index values in error messages from PG index violation errors.

### Changed

- [25bde454](https://github.com/appsignal/appsignal-ruby/commit/25bde454f82776f8d2ea1fd4dbb00a73e414076e) patch - Order the config options alphabetically in diagnose report output.
- [fe226e99](https://github.com/appsignal/appsignal-ruby/commit/fe226e99f262bfa46e7a7630defe2fe90f8a3a13) patch - Use the `filter_parameters` and `filter_session_data` options to filter out specific parameter keys or session data keys for the experimental Span API. Previously only the (undocumented) `filter_data_keys` config option was available to filter out all kinds of app data.
- [fe226e99](https://github.com/appsignal/appsignal-ruby/commit/fe226e99f262bfa46e7a7630defe2fe90f8a3a13) patch - Standardize diagnose validation failure message. Explain the diagnose request failed and why.
- [fe226e99](https://github.com/appsignal/appsignal-ruby/commit/fe226e99f262bfa46e7a7630defe2fe90f8a3a13) patch - Bump agent to v-5b63505
  
  - Only filter parameters with the `filter_parameters` config option.
  - Only filter session data with the `filter_session_data` config option.
- [3ad95ea5](https://github.com/appsignal/appsignal-ruby/commit/3ad95ea5dd8a9488d293a652231950bd4a721e6c) patch - Bump agent to v-0db01c2
  
  - Add `log_level` config option in extension.
  - Deprecate `debug` and `transaction_debug_mode` option in extension.

### Deprecated

- [84b1ba18](https://github.com/appsignal/appsignal-ruby/commit/84b1ba18e50440e5c71d27319e560c5df180d0df) patch - Deprecate "debug" and "transaction_debug_mode" config options in favor of the new "log_level"
  config option.

## 3.0.15

- [b40b3b4f](https://github.com/appsignal/appsignal-ruby/commit/b40b3b4f5264c6b69f9515b53806435258c73086) patch - Print String values in the diagnose report surrounded by quotes. Makes it more clear that it's a String value and not a label we print.
- [fd6faf16](https://github.com/appsignal/appsignal-ruby/commit/fd6faf16d9feb73c3076c2e1283f6101dc4abf97) patch - Bump agent to 09308fb
  
  - Update sql_lexer dependency with support for reversed operators in queries.
  - Add debug level logging to custom metrics in transaction_debug_mode.
  - Add hostname config option to standalone agent.

## 3.0.14

- [c40f6d75](https://github.com/appsignal/appsignal-ruby/commit/c40f6d759e8d516cc47bd55cc83bfcb680fbd1ea) patch - Add minutely probe that collects metrics for :class_serial and :global_constant_state from RubyVM.
- [7c18fb6d](https://github.com/appsignal/appsignal-ruby/commit/7c18fb6db0c72f32adb6803ccde957963977008a) patch - Bump agent to 7376537
  
  - Support JSON PostgreSQL operator in sql_lexer.
  - Do not strip comments from SQL queries.
- [8d7b80ea](https://github.com/appsignal/appsignal-ruby/commit/8d7b80eafc203c295db037f2547f74a2f217f93f) patch - Add configuration option for the AppSignal agent StatsD server. This is on by default, but you can disable it with `enable_statsd: false`.

## 3.0.13

- [5c202185](https://github.com/appsignal/appsignal-ruby/commit/5c20218526e026ab436854508ccfe26ca55e8f15) patch - Bump agent to v-0318770.
  
  - Improve Dokku platform detection. Do not disable host metrics on
    Dokku.
  - Report CPU steal metric.

## 3.0.12

- [7f3af841](https://github.com/appsignal/appsignal-ruby/commit/7f3af8418f830a7384c10b309e1aeb8ee32c5742) patch - Bump agent to 0f40689
  
  - Add Apple Darwin ARM alias.
  - Improve appsignal.h documentation.
  - Improve transaction debug log for errors.
  - Fix agent zombie/defunct issue on containers without process reaping.

## 3.0.11

- [8e3ec789](https://github.com/appsignal/appsignal-ruby/commit/8e3ec78943acf7c533c3703c3961e19c49dcd5aa) patch - Bump agent to v-891c6b0. Add experimental Apple Silicon M1 ARM64 build.

## 3.0.10

- [88f7d585](https://github.com/appsignal/appsignal-ruby/commit/88f7d5850f57777c98f56190dc35ff37eface542) patch - Bump agent to c2024bf with appsignal-agent diagnose timing issue fix when reading the report and improved filtering for HTTP request transmission logs.

## 3.0.9

- [44dd4bdc](https://github.com/appsignal/appsignal-ruby/commit/44dd4bdc824ec88337b75791c1870358a4aa274f) patch - Check Rails.backtrace_cleaner method before calling the method. This prevents a NoMethodError from being raised in some edge cases.

## 3.0.8

- [5f94712d](https://github.com/appsignal/appsignal-ruby/commit/5f94712d3406898f58bea133b8bf3578d6fbbe22) patch - Add the `APPSIGNAL_BUILD_FOR_LINUX_ARM` flag to allow users to enable the experimental Linux ARM build for 64-bit hosts. Usage: `export APPSIGNAL_BUILD_FOR_LINUX_ARM=1 bundle install`. Please be aware this is an experimental build. Please report any issue you may encounter at our [support email](mailto:support@appsignal.com).

## 3.0.7

- [27f9b178](https://github.com/appsignal/appsignal-ruby/commit/27f9b178c20006ee15e69bdf878f3a0c9975b1f4) patch - Bump agent to 6caf6d0. Replaces curl HTTP client and includes various other maintenance updates.
- [665d883a](https://github.com/appsignal/appsignal-ruby/commit/665d883a529e5c14b28e73eeb3ae6410deb3e182) patch - Improve Puma plugin stats collection. Instead of starting the AppSignal gem in the main process we send the stats to the AppSignal agent directly using StatsD. This should improve compatibility with phased restarts. If you use `prune_bundler`, you will need to add AppSignal to the extra `extra_runtime_dependencies` list.
  
  ```
  # config/puma.rb
  plugin :appsignal
  extra_runtime_dependencies ["appsignal"]
  ```

## 3.0.6

- [d354d79b](https://github.com/appsignal/appsignal-ruby/commit/d354d79b293fd549e66cae60d805d1b1e9e9d2d8) patch - Add Excon integration. Track requests and responses from the Excon gem.
- [4c32e818](https://github.com/appsignal/appsignal-ruby/commit/4c32e8180b797d7987c67b68720c6a5d22935333) patch - Support Redis eval statements better by showing the actual script that was performed. Instead of showing `eval ? ? ?` (for a script with 2 arguments), show `<script> ? ?`, where `<script>` is whatever script was sent to `Redis.new.eval("<script>")`.

## 3.0.5

- [4bddac36](https://github.com/appsignal/appsignal-ruby/commit/4bddac3618ccea03c165eec53cee90e222b68cd6) patch - Skip empty HTTP proxy config. When any of the HTTP proxy config returns an
  empty string, skip this config. This fixes installation issues where an empty
  String is used as a HTTP proxy, causing a RuntimeError upon installation.

## 3.0.4

- [6338e822](https://github.com/appsignal/appsignal-ruby/commit/6338e8227c674ea7bbe6f55cdfde784fa9f5048f) patch - Drop logger level to debug. Reduce the output on the "info" level and only show
  these messages in debug mode. This should reduce the noise for users running
  AppSignal with the STDOUT logger, such as is the default on Heroku.

## 3.0.3
- Fix deprecation message for set_error namespace argument. PR #712
- Fix example code for Transaction#set_namespace method. PR #713
- Fix extension fallbacks on extension installation failure, that caused
- NoMethodErrors. PR #720
- Bump agent to v-75e76ad. PR #721

## 3.0.2
- Fix error on Rails boot when `enable_frontend_error_catching` is `true`.
  PR #711

## 3.0.1
- Fix error occurring on APPSIGNAL_DNS_SERVER environment variable option
  parsing. PR #709

## 3.0.0

Please read our [upgrade from version 2 to 3 guide][upgrade3] before upgrading.

[upgrade3]: https://docs.appsignal.com/ruby/installation/upgrade-from-2-to-3.html

- Drop Ruby 1.9 support. PR #683, #682, #688, #694
- Require Ruby 2.0 or newer for gem. PR #701
- Use Module.prepend for all gem integrations. Fixes #603 in combination with
  other gems that provide instrumentation for gems. PR #683
- Remove deprecated integrations, classes, methods and arguments. PR #685, #686
- Deprecate `set_error` and `send_error` error helpers `tags` and `namespace`
  arguments. PR #702
- Add Sidekiq error handler. Report more Sidekiq errors that happen around job
  execution. PR #699

## 2.11.10
- Backport extension fallbacks on extension installation failure, that caused
  NoMethodErrors. PR #736

## 2.11.9
- Fix and simplify Ruby method delegation for object method instrumentation in
  the different Ruby versions. PR #706

## 2.11.8
- Mark minutely probe thread as fork-safe by @pixeltrix. PR #704

## 2.11.7
- Fix ActionCable integration in test environment using `stub_connection`.
  PR #705

## 2.11.6
- Prepend Sidekiq middleware to wrap all Sidekiq middleware. Catches more
  errors and provide more complete performance measurements. PR #698

## 2.11.5
- Add more detailed logging to finish_event calls when the event is unknown, so
  we know what event is being tried to finish. Commit
  c888a04d1b9ac947652b29c111c650fb5a5cf71c

## 2.11.4
- Support Ruby 3.0 for Object method instrumentation with keyword arguments
  (https://docs.appsignal.com/ruby/instrumentation/method-instrumentation.html)
  PR #693

## 2.11.3
- Support Shoryuken batch workers. PR #687

## 2.11.2
- Support Ruby 3.0. PR #681
- Support breadcrumbs. PR #666
- Log Ruby errors on extension download. PR #679
- Fix Ruby 1.9 build. PR #680

## 2.11.1
- Support AS notifications instrumenters that use `start` and `finish`.
- Updated agent with better logging and an IO stats fix.
- ActionMailer magic dashboard

## 2.11.0
- Track queue time regardless of namespace. Support custom namespaces. PR #602
- Improve deprecation message from frontend error middleware. PR #620
- Report Ruby environment metadata. PR #621, #627, #619, #618
- Refactor: Move minutely probes to their own files and modules. PR #623
- Allow custom action names in Que integration. Needed for Active Job
  integration. PR #628
- Add Active Job support. Support Active Job without separate AppSignal
  integration of the background job library. Add support for previously
  unsupported Active Job adapters. Adapters that were previously already
  supported (Sidekiq, DelayedJob and Resque) still work in this new setup.
  PR #629
- Add automatic Resque integration. Remove manual Resque and Resque Active Job
  integrations. PR #630
- Fix issue with unknown events from being reported as often for long running
  agents. Commit ba9afb538f44c68b8035a8cf40a39d89bc77b021
- Add support for Active Job priority. PR #632
- Track Active Job job metrics for magic dashboard. PR #633
- Report Sidekiq `jid` (job id) as transaction id, reported as "request_id" on
  AppSignal.com. PR #640
- Always report Active Job ID, an internal ID used by Active Job. PR #639
- Support Delayed::Job jobs without specific method name, using
  `Delayed::Job.enqueue`. PR #642
- Print warnings using Kernel.warn. PR #648
- Update AuthCheck class to use DeprecationMessage helper. PR #649
- Print extension load error when AppSignal is loaded. PR #651

## 2.10.12
- Fix `working_directory_path` config option loaded from environment variables.
  PR #653

## 2.10.11
- Fix extension install report status output in `appsignal diagnose`. PR #636
- Support setting a specific configuration file to load with the
  `Appsignal::Config` initializer. PR #638

## 2.10.10
- Bump agent to v-4548c88. PR #634
  - Fix issue with host metrics values being reported as "Infinity".

## 2.10.9
- Use http proxy if configured when downloading agent. PR #606
- Clear event details cache every 48 hours.
  Commit eb5e899db69fcd7cfa221567bfd6ac04f2654c9c
- Add support for Resque ActiveJob queue time reporting. PR #616

## 2.10.8
- Fix failed checksum error log. PR #609
- Fix DelayedJob action name detection for objects that listen to the `[]`
  method and return a non-String value. #611
- CI test build improvements. PR #607, #608, #614

## 2.10.7
- Revert fix for compatibility with the `http_logger` gem. PR #604.
  For more information, see issue #603 about our reasoning and discussion.

## 2.10.6
- Check if queued payloads are for correct app and not expired

## 2.10.5
- Improve Ruby 1.9 compatibility. PR #591
- Add grape.skip_appsignal_error request env. PR #588
  More information: https://docs.appsignal.com/ruby/integrations/grape.html
- Fix compatibility with the `http_logger` gem. Fix `SystemStackError`. PR #597

## 2.10.4
- Fix `Appsignal::Transaction#set_http_or_background_action` helper (used by
  `Appsignal.monitor_transaction`), to allow overwriting the action name of a
  `Transaction` with `Appsignal.set_action`. PR #594
- Move build to Semaphore. PR #587, #590 and #592

## 2.10.3
- Only warn about reused transactions once. Repeated occurrences are logged as
  debug messages. PR #585

## 2.10.2
- Fix wait_for test suite helper. PR #581
- Fix exception handling of config file issues. PR #582
  - The improvement introduced in #517 didn't fetch the class name correctly
    causing an error on most scenarios.

## 2.10.1
- Update to more recent bundled SSL CA certificates. PR #577
- Remove TLS version lock from transmitter used by diagnose command, preventing
  it from sending the report. Was locked to TLS v1, now uses the Ruby default.
  PR #580

## 2.10.0
- Rescue errors while parsing `appsignal.yml` file. It will prints a warning
  instead. PR #517
- Refactoring: Reduce class variable usage. PR #520
- Bump log level about starting new transactions while a transaction is already
  active from debug to a warning. PR #525
- Refactoring: Add internal AppSignal test helpers and other test suite
  refactorings. PR #536, #537, #538, #539
- Fix internal Rakefile loading on Ruby 1.9.3. PR #541
- Add a `--no-color` option to the `appsignal install` command. PR #550
- Add output coloring to `appsignal diagnose` warnings. PR #551
- Add validation for empty Push API key. Empty Push API key values will no
  longer start AppSignal. PR #569
- Deprecate the JSExceptionCatcher middleware in favor of our new front-end
  JavaScript integration (https://docs.appsignal.com/front-end/). PR #572

## 2.9.18
- Bump agent to v-c348132
  - Improve transmitter logging on timeout
  - Improve queued payloads transmitter. Should prevent payloads being sent
    multiple times.
  - Add transaction debug mode
  - Wrap Option in Mutex in TransactionInProgess

## 2.9.17
- Handle missing file and load errors from `application.rb` in `appsignal
  install` for Rails apps. PR #568
- Support minutely probes for Puma in clustered mode. PR #570
  See the installation instructions for the Puma plugin:
  https://docs.appsignal.com/ruby/integrations/puma.html

## 2.9.16
- Check set_error arguments for Exceptions. PR #565
- Bump agent to v-1d8917f - commit 737d6b1b8fc9cd2c0564050bb04246d9267dceb7
  - Only attempt to send queued payloads if we have a successful transmission.

## 2.9.15
- Bump agent to v-690f4b8 - commit cf4f3787395c8524079f3bed3b2c2367296482a9
  - Validate transmission_interval option.

## 2.9.14
- Support mirrors when downloading the agent & extension. PR #558
- Support Que's upcoming 1.0.0 release. PR #557

## 2.9.13
- Bump agent to v-e1c9363
  - Detect revision from Heroku dynos automatically when Dyno Metadata is
    turned on.

## 2.9.12
- Bump agent to v-a3e0f83 - commit 3d94dd42645922214fc2f5bc09cfa7c597323198
  - Better detect zombie/defunct processes on containers and consider the
    processes dead. This should improve the appsignal-agent start behavior.
- Fix Sequel install hook version detection mismatch. PR #553
- Improve support for older Sidekiq versions. PR #555

## 2.9.11
- Bump agent to v-a718022
  - Fix container CPU runtime metrics.
    See https://github.com/appsignal/probes-rs/pull/38 for more information.
  - Improve host metrics calculations accuracy for counter metrics.
    See https://github.com/appsignal/probes-rs/pull/40 for more information.
  - Support Kernel 4.18+ format of /proc/diskstats file parsing.
    See https://github.com/appsignal/probes-rs/pull/39 for more information.

## 2.9.10
- Fix Puma minutely probe start where `daemonize` is set to `true`. PR #548

## 2.9.9
- Fix error in the ActiveSupport::Notifications integration when a transaction
  gets completed during event instrumentation. PR #532
- Fix Redis constant load error. PR #543
- Add more logging for errors in debug mode. PR #544
- Deprecate notify_of_deploy command. PR #545
- Always call the block given to `Appsignal.monitor_transaction` and log errors
  from the helper even when AppSignal is not active. PR #547

## 2.9.8
- Fix Ruby 1.9 compatibility in extension installation. PR #531

## 2.9.7
- Fix minutely probes not being loaded from Rails initializers. PR #528

## 2.9.6
- Print link to diagnose docs on unsuccessful demo command. PR #512
- Add support for minutely probe `.dependencies_present?` check. PR #523
- Do not activate Sidekiq minutely probe on unsupported Redis gem versions.
  PR #523.

## 2.9.5
- Improve logging in minutely probes. PR #508
- Delay the first minutely probe for a bit, since it might take some
  time for dependencies to initialize. PR #511

## 2.9.4
- Log error backtraces in minutely probes as debug messages. PR #495
- Don't add cluster behavior in Puma single mode. PR #504
- Only register ActionView event formatter in Rails. PR #503
- Convert Sidekiq latency from seconds to ms. PR #505

## 2.9.3
- Remove GCProbe. PR #501

## 2.9.2
- Fix Puma.stats calls. PR #496
- Only send Puma metrics if available. PR #497
- Track memory metrics of the current process. PR #499

## 2.9.1
- Fix memory leak in custom metrics key names.
  Commit 9064e2ccfd19ee05c333d0ecda4deafdd743629e

## 2.9.0
- Fix installations using git source. PR #455
- Track installation results in installation report. PR #450
- Fix Rails 6 deprecation warnings. PR #460, PR #478, PR #483
- Improve error handling in minutely probes mechanism. PR #467
- Only allow one minutely probe thread to run at a time. PR #469
- Change minutely probes register method to use a key for every probe. PR #473
- Send Sidekiq metrics by default. PR #471
- Send MongoDB metrics by default. PR #472
- Fix Ruby 2.6 deprecation warnings. PR #479
- Support blocks for `Appsignal.send_error` to add more metadata to the
  AppSignal transaction. PR #481
- Move instrumentation & metrics helpers to modules. PR #487
- Add Puma minutely probe. PR #488
- Log invalid EventFormatter registrations as errors. PR #491
- Support container CPU host metrics.
  Commit f2fca1ec5a850cd84fbc8cefe63af8f039ebb155
- Support StatsD server in agent.
  Commit f2fca1ec5a850cd84fbc8cefe63af8f039ebb155
- Fix samples being reported for multiple namespaces.
  Commit f2fca1ec5a850cd84fbc8cefe63af8f039ebb155
- Report memory and swap usage in percent using the memory_usage and
  swap_usage metrics. Commit f2fca1ec5a850cd84fbc8cefe63af8f039ebb155

## 2.8.4
- Log memory usage of agent if high.
  Commit 46cf3770e13eff9f5fccbf8a4525a8dbfd8eeaad
- Fix `Appsignal::Transaction.pause!`. PR #482

## 2.8.3
- Fix multi user permission issue for agent directories and files.
  Commit ab1b35f850777d5999b41627d75be0b3904bc0a1

## 2.8.2
- Remove Bundler requirement from diagnose command. PR #451
- Fix Delayed::Job action name reporting for structs. PR #463

## 2.8.1
- Fix installation on Ruby 2.6 for libc and musl library builds. PR #453

## 2.8.0
- Group extension and agent tests in diagnose output. PR #437
- Add diagnose --[no-]send-report option. PR #438
- Print deprecation warnings to STDOUT as well. PR #439
- Diagnose command starts the AppSignal logger. PR #440
- Send appsignal.log file contents with diagnose report. PR #442
- Track source of config option for diagnose report. PR #444
- Link back to AppSignal diagnose report page. Claim you reports. PR #445
- Print only last 10 lines of files in diagnose report output. PR #442 & #447
- Support container memory host metrics better. PR #448
- Build dynamic musl extension library. Supports JRuby for musl builds. PR #448
- Change `files_world_accessible` permissions to not make files executable.
  PR #448
- Make agent debug logging for disk IO metrics more robust. PR #448

## 2.7.3 Beta
- Add user and group context to diagnose report. PR #436
- Add user and group context to agent logs. PR #436
- Fixes for running with multiple users

## 2.7.2
- Change the order of instructions in the install script for Rails. PR #433
- Fix linking issues on multi-stage build setups. PR #434

## 2.7.1
- Improve error log on unsupported architecture and build combination on
  install. PR #426
- Improve performance when garbage collection profiling is disabled. PR #429

## 2.7.0
- Detect Kubernetes containers as containers for `running_in_container`
  config option. Commit 60822aac24ccc394df073091c64f05096455942d.
- Fix in memory logger initialization. PR #416
- Organize classes in their own files. PR #417
- Move tag value limit handling to extension. PR #418
- Add working_directory_path config option. PR #421
- Use doubles values in custom metrics functions. PR #422
- Bump agent to e41c3c0. Commit 8056af037f82eda156c5946911012e5c742b5664

## 2.6.1
- Remove request_headers warning and use sane default. PR #410
- Fix metrics format for internal agent metrics. PR #411

## 2.6.0
- Enable frozen strings by default. PR #384
- Add `revision` config option. PR #388
- Avoid generating unique action names for Padrino. PR #393
- Add `request_headers` filter configuration. PR #395
- Support tags for custom metrics. PR #398
- Add filter_session_data config option. PR #402 & #409
- Move default hostname behavior to extension. PR #404
- Add `request_headers` config to installation step. PR #406
- Rename ParamsSanitizer to HashSanitizer. PR #408
- Fix empty action name issue. Commit b292c2c93c8935ab54fc4d16598fa534c9cc9c90

## 2.5.3
- Fix Sidekiq action names containing arguments. PR #401

## 2.5.2
- Support Sidekiq delay extension for ActiveRecord instances. If using this
  feature in your app, an update is strongly recommended! PR #387
- Improve custom event formatter registration. An event formatter can now be
  registered in a Rails initializer after AppSignal has been loaded/started.
  PR #397

## 2.5.1
- Improve internal sample storage in agent.
  Commit 2c8eae26685c7a1517cf2e57b44edd1557a502f2
- No longer set _APPSIGNAL_AGENT_VERSION environment variable. PR #385

## 2.5.0
- Fix Capistrano config overrides. PR #375
- Add JRuby beta support. PR #376
- Fix locking issue on diagnose mode run.
  Commit e6c6de811f8115a73050fc865e89dd4945ddec57
- Increase stored length of error messages.
  Commit e6c6de811f8115a73050fc865e89dd4945ddec57

## 2.4.3
- Store more details for Redis events. PR #374

## 2.4.2
- Store agent architecture rather than platform. PR #367
- Improve documentation for `Appsignal.monitor_transaction` better.
  Commit e53987ba36a79fc8883f2e59322946297ddee773
- Change log level from info to debug for value comparing failures.
  Commit ecef28b28edaff46b95f53a916c93021dc763160
- Collect free memory host metric.
  Commit ecef28b28edaff46b95f53a916c93021dc763160
- Fix crashes when Set wasn't required before AppSignal, such as in the CLI.
  PR #373

## 2.4.1
- Add Que integration. PR #361
- Support Sidekiq delayed extension job action names better. Now action names
  are reported as their class and class method name (`MyClass.method`), rather
  than `Sidekiq::Extensions::DelayedClass#perform` for all jobs through that
  extension. PR #362
- Support Sidekiq Enterprise encrypted values. PR #365
- Use musl build for older libc systems. PR #366

## 2.4.0
- Add separate GNU linux build. PR #351 and
  Commit d1763f4dcb685608468a73f3192226f60f66b217
- Add separate FreeBSD build
  Commit d1763f4dcb685608468a73f3192226f60f66b217
- Fix crashes when using a transaction from multiple processes in an
  unsupported way.
  Commit d1763f4dcb685608468a73f3192226f60f66b217
- Auto restart agent when none is running
  Commit d1763f4dcb685608468a73f3192226f60f66b217
- Add `appsignal_user` Capistrano config option. PR #355
- Track Exception-level exceptions. PR #356
- Add tags and namespace arguments to `Appsignal.listen_for_error`. PR #357
- Revert Sidekiq delayed extension job action names fix.
  Commit 9b84a098604de5ef5e52645ba7fcb09d84f66eaa

## 2.3.7
- Support Sidekiq delayed extension job action names better. Now action names
  are reported as their class and class method name (`MyClass.method`), rather
  than `Sidekiq::Extensions::DelayedClass#perform` for all jobs through that
  extension. PR #348

## 2.3.6
- Allow configuration of permissions of working directory. PR #336
- Fix locking bug that delayed extension shutdown.
  Commit 51d90bb1207affc2c88f7cff5035a2c36acf9784
- Log extension start with app revision if present
  Commit 51d90bb1207affc2c88f7cff5035a2c36acf9784

## 2.3.5

Yanked

## 2.3.4
- Fix naming for ActiveJob integration with DelayedJob. PR #345

## 2.3.3
- Accept mixed case env variable values for the `true` value. PR #333
- Don't record sensitive HTTP_X_AUTH_TOKEN header. PR #334
- Support dry run option for Capistrano 3.5.0 and higher. PR #339
- Agent and extension update. Improve agent connection handling. Commit
  e75d2f9b520d46f6cd0266b484b2c26c3bdc8882

## 2.3.2
- Improve Rake argument handling. Allow for more detailed view of which
  arguments a tasks receives. PR #328

## 2.3.1
- Fix ActiveSupport::Notifications hook not supporting non-string names for
  events. PR #324

## 2.3.0
- Fix Shoryuken instrumentation when body is a string. PR #266
- Enable ActiveSupport instrumentation at all times. PR #274
- Add parameter filtering for background jobs. Automatically uses the AppSignal
  parameter filtering. PR #280
- Improve log messages for transactions. PR #293
- Remove thread_safe dependency. PR #294
- Add `Transaction#params` attribute for custom parameters. PR #295
- Fix queue time on DelayedJob integration. PR #297
- Add ActionCable support. PR #309
- Finish ActiveSupport notifications events when they would encounter a `raise`
  or a `throw`. PR #310
- Add `ignore_namespaces` option. PR #312
- Truncate lengthy parameter values to 2000 characters.
  Commit 65de1382f5f453b624781cde6e0544c89fdf89ef and
  d3ca2a545fb22949f3369692dd57d49b4936c739.
- Disable gracefully on Microsoft Windows. PR #313
- Add tags and namespace arguments to `Appsignal.set_error`. PR #317

## 2.2.1
- Fix support for Rails 5.1. PR #286
- Fix instrumentation that would report a duration of `0ms` for all DataMapper
  queries. PR #290
- Finish events when `Appsignal.instrument` encounters a `raise` or a `throw`.
  PR #292

## 2.2.0
- Support Ruby 2.4 better. PR #234
- Initial setup for documenting the Ruby gem's code. PR #243
- Move `running_in_container` auto detection to extension for easy reuse.
  PR #249
- Allow overriding of action and namespace for a transaction. PR #254
- Prefix all agent configuration environment variables with an underscore to
  separate the two usages. PR #258
- Force agent to run in diagnostic mode even when the user config is set to
  `active: false`. PR #260
- Stub JS error catching endpoint when not active. PR #263
- Use better event names for Padrino integration. PR #265
- No longer gzip payloads send by the Ruby gem transmitter. PR #269
- Send diagnostics data report to AppSignal on request. PR #270
- When JS exception endpoint payload is empty return 400 code. PR #271
- Remove hardcoded DNS servers from agent and add config option. PR #278

## 2.1.2
- Fix error with Grape request methods defined with symbols. PR #259

## 2.1.1
- Fix DNS issue related to the musl build.
  Commit 732c877de8faceabe8a977bf80a82a6a89065c4d and
  84e521d20d4438f7b1dda82d5e9f1f533ae27c4b
- Update benchmark and add load test. PR #248
- Fix configuring instrument Redis and Sequel from env. PR #257

## 2.1.0
- Add support for musl based libc (Alpine Linux). PR #229
- Implement `Appsignal.is_ignored_error?` and `Appsignal.is_ignored_action?`
  logic in the AppSignal extension. PR #224
- Deprecate `Appsignal.is_ignored_error?`. PR #224
- Deprecate `Appsignal.is_ignored_action?`. PR #224
- Enforce a coding styleguide with RuboCop. PR #226
- Remove unused `Appsignal.agent` attribute. PR #244
- Deprecate unused `Appsignal::AuthCheck` logger argument. PR #245

## 2.0.6
- Fix `Appsignal::Transaction#record_event` method call. PR #240

## 2.0.5
- Improved logging for agent connection issues.
  Commit cdf9d3286d704e22473eb901c839cab4fab45a6f
- Handle nil request/environments in transactions. PR #231

## 2.0.4
- Use consistent log format for both file and STDOUT logs. PR #203
- Fix log path in `appsignal diagnose` for Rails applications. PR #218, #222
- Change default log path to `./log` rather than project root for all non-Rails
  applications. PR #222
- Load the `APPSIGNAL_APP_ENV` environment configuration option consistently
  for all integrations. PR #204
- Support the `--environment` option on the `appsignal diagnose` command. PR
  #214
- Use the real system `/tmp` directory, not a symlink. PR #219
- Run the AppSignal agent in diagnose mode in the `appsignal diagnose` command.
  PR #221
- Test for directory and file ownership and permissions in the
  `appsignal diagnose` command. PR #216
- Test if current user is `root` in the `appsignal diagnose` command. PR #215
- Output last couple of lines from `appsignal.log` on agent connection
  failures.
- Agent will no longer fail to start if no writable log path is found.
  Commit 8920865f6158229a46ed4bd1cc98d99a849884c0, change in agent.
- Internal refactoring of the test suite and the `appsignal install` command.
  PR #200, #205

## 2.0.3
- Fix JavaScript exception catcher throwing an error on finishing a
  transaction. PR #210

## 2.0.2
- Fix Sequel instrumentation overriding existing logic from extensions. PR #209

## 2.0.1
- Fix configuration load order regression for the `APPSIGNAL_PUSH_API_KEY`
  environment variable's activation behavior. PR #208

## 2.0.0
- Add `Appsignal.instrument_sql` convenience methods. PR #136
- Use `Appsignal.instrument` internally instead of ActiveSupport
  instrumentation. PR #142
- Override ActiveSupport instrument instead of subscribing. PR #150
- Remove required dependency on ActiveSupport. Recommended you use
  `Appsignal.instrument` if you don't need `ActiveSupport`. PR #150 #142
- Use have_library to link the AppSignal extension `libappsignal`. PR #148
- Rename `appsignal_extension.h` to `appsignal.h`.
  Commit 9ed7c8d83f622d5a79c5c21d352b3360fd7e8113
- Refactor rescuing of Exception. PR #173
- Use GC::Profiler to track garbage collection time. PR #134
- Detect if AppSignal is running in a container or Heroku. PR #177 #178
- Change configuration load order to load environment settings after
  `appsignal.yml`. PR #178
- Speed up payload generation by letting the extension handle it. PR #175
- Improve `appsignal diagnose` formatting and output more data. PR #187
- Remove outdated `appsignal:diagnose` rake tasks. Use `appsignal diagnose`
  instead. PR #193
- Fix JavaScript exception without names resulting in errors themselves. PR #188
- Support namespaces in Grape routes. PR #189
- Change STDOUT output to always mention "AppSignal", not "Appsignal". PR #192
- `appsignal notify_of_deploy` refactor. `--name` will override any
  other `name` config. `--environment` is only required if it's not set in the
  environment. PR #194
- Allow logging to STDOUT. Available for the Ruby gem and C extension. The
  `appsignal-agent` process will continue log to file. PR #190
- Remove deprecated methods. PR #191
- Send "ruby" implementation name with version number for better identifying
  different language implementations. PR #198
- Send demonstration samples to AppSignal using the `appsignal install`
  command instead of asking the user to start their app. PR #196
- Add `appsignal demo` command to test the AppSignal demonstration samples
  instrumentation manually and not just during the installation. PR #199

## 1.3.6
- Support blocks arguments on method instrumentation. PR #163
- Support `APPSIGNAL_APP_ENV` for Sinatra. PR #164
- Remove Sinatra install step from "appsignal install". PR #165
- Install Capistrano integration in `Capfile` instead of `deploy.rb`. #166
- More robust handing of non-writable log files. PR #160 #158
- Cleaner internal exception handling. PR #169 #170 #171 #172 #173
- Support for mixed case keywords in sql lexing. appsignal/sql_lexer#8
- Support for inserting multiple rows in sql lexing. appsignal/sql_lexer#9
- Add session_overview to JS transaction data.
  Commit af2d365bc124c01d7e9363e8d825404027835765

## 1.3.5

- Fix SSL certificate config in appsignal-agent. PR #151
- Remove mounted_at Sinatra middleware option. Now detected by default. PR #146
- Sinatra applications with middleware loading before AppSignal's middleware
  would crash a request. Fixed in PR #156

## 1.3.4

- Fix argument order for `record_event` in the AppSignal extension

## 1.3.3

- Output AppSignal environment on `appsignal diagnose`
- Prevent transaction crashes on Sinatra routes with optional parameters
- Listen to `stage` option to Capistrano 2 for automatic environment detection
- Add `appsignal_env` option to Capistrano 2 to set a custom environment

## 1.3.2
- Add method to discard a transaction
- Run spec suite with warnings, fixes for warnings

## 1.3.1
- Bugfix for problem when requiring config from installer

## 1.3.0
- Host metrics is now enabled by default
- Beta of minutely probes including GC metrics
- Refactor of param sanitization
- Param filtering for non-Rails frameworks
- Support for modular Sinatra applications
- Add Sinatra middleware to `Sinatra::Base` by default
- Allow a new transaction to be forced by sinatra instrumentation
- Allow hostname to be set with environment variable
- Helpers for easy method instrumentation
- `Appsignal.instrument` helper to easily instrument blocks of code
- `record_event` method to instrument events without a start hook
- `send_params` is now configurable via the environment
- Add DataMapper integration
- Add webmachine integration
- Allow overriding Padrino environment with APPSIGNAL_APP_ENV
- Add mkmf.log to diagnose command
- Allow for local install with bundler `bundle exec rake install`
- Listen to `stage` option to Capistrano 3 for automatic environment detection
- Add `appsignal_env` option to Capistrano 3 to set a custom environment

## 1.2.5
- Bugfix in CPU utilization calculation for host metrics

## 1.2.4
- Support for adding a namespace when mounting Sinatra apps in Rails
- Support for negative numbers and ILIKE in the sql lexer

## 1.2.3
- Catch nil config for installer and diag
- Minor performance improvements
- Support for arrays, literal value types and function arguments in sql lexer

## 1.2.2
- Handle out of range numbers in queue length and metrics api

## 1.2.1
- Use Dir.pwd in CLI install wizard
- Support bignums when setting queue length
- Support for Sequel 4.35
- Add env option to skip errors in Sinatra
- Fix for queue time calculation in Sidekiq (by lucasmazza)

## 1.2.0
- Restart background thread when FD's are closed
- Beta version of collecting host metrics (disabled by default)
- Hooks for Shuryoken
- Don't add errors from env if raise_errors is off for Sinatra

## 1.1.9
- Fix for race condition when creating working dir exactly at the same time
- Make diag Rake task resilient to missing config

## 1.1.8
- Require json to fix problem with using from Capistrano

## 1.1.7
- Make logging resilient for closing FD's (daemons gem does this)
- Add support for using Resque through ActiveJob
- Rescue more exceptions in json generation

## 1.1.6
- Generic Rack instrumentation middleware
- Event formatter for Faraday
- Rescue and log errors in transaction complete and fetching params

## 1.1.5
- Support for null in sql sanitization
- Add require to deploy.rb if present on installation
- Warn when overwriting already existing transaction
- Support for x86-linux
- Some improvements in debug logging
- Check of log file path is writable
- Use bundled CA certs when installing agent

## 1.1.4
- Better debug logging for agent issues
- Fix for exception with nil messages
- Fix for using structs as job params in Delayed Job

## 1.1.3
- Fix for issue where Appsignal.send_exception clears the current
  transaction if it is present
- Rails 3.0 compatibility fix

## 1.1.2
- Bug fix in notify of deploy cli
- Better support for nil, true and false in sanitization

## 1.1.1
- Collect global metrics for GC durations (in beta, disabled by default)
- Collect params from Delayed Job in a reliable way
- Collect perams for Delayed Job and Sidekiq when using ActiveJob
- Official Grape support
- Easier installation using `bundle exec appsignal install`

## 1.1.0
Yanked

## 1.0.7
- Another multibyte bugfix in sql sanizitation

## 1.0.6
- Bugfix in sql sanitization when using multibyte utf-8 characters

## 1.0.5
- Improved sql sanitization
- Improved mongoid/mongodb sanitization
- Minor performance improvements
- Better handling for non-utf8 convertible strings
- Make gem installable (but not functional) on JRuby

## 1.0.4
- Make working dir configurable using `APPSIGNAL_WORKING_DIR_PATH` or `:working_dir_path`

## 1.0.3
- Fix bug in completing JS transactions
- Make Resque integration robust for bigger payloads
- Message in logs if agent logging cannot initialize
- Call `to_s` on DJ id to see the id when using MongoDB

## 1.0.2
- Bug fix in format of process memory measurements
- Event formatter for `instantiation.active_record`
- Rake integration file for backwards compatibility
- Don't instrument mongo-ruby-driver when transaction is not present
- Accept method calls on extension if it's not loaded
- Fix for duplicate notifications subscriptions when forking

## 1.0.1
- Fix for bug in gem initialization when using `safe_yaml` gem

## 1.0.0
- New version of event formatting and collection
- Use native library and agent
- Use API V2
- Support for Mongoid 5
- Integration into other gems with a hooks system
- Lots of minor bug fixes and improvements

## 0.11.15
- Improve Sinatra support

## 0.11.14
- Support ActiveJob wrapped jobs
- Improve proxy support
- Improve rake support

## 0.11.13
- Add Padrino support
- Add Rake task monitoring
- Add http proxy support
- Configure Net::HTTP to only use TLS
- Don't send queue if there is no content
- Don't retry transmission when response code is 400 (no content)
- Don't start Resque IPC server when AppSignal is not active
- Display warning message when attempting to send a non-exception to `send_exception`
- Fix capistrano 2 detection
- Fix issue with Sinatra integration attempting to attach an exception to a transaction that doesn't exist.

## 0.11.12
- Sanitizer will no longer inspect unknown objects, since implementations of inspect sometimes trigger unexpected behavior.

## 0.11.11
- Reliably get errors in production for Sinatra

## 0.11.10
- Fix for binding bug in exceptions in Resque
- Handle invalidly encoded characters in payload

## 0.11.9
- Fix for infinite attempts to transmit if there is no valid api key

## 0.11.8
- Add frontend error catcher
- Add background job metadata (queue, priority etc.) to transaction overview
- Add APPSIGNAL_APP_ENV variable to Rails config, so you can override the environment
- Handle http queue times in microseconds too

## 0.11.7
- Add option to override Job name in Delayed Job

## 0.11.6
- Use `APPSIGNAL_APP_NAME` and `APPSIGNAL_ACTIVE` env vars in config
- Better Sinatra support: Use route as action and set session data for Sinatra

## 0.11.5
- Add Sequel gem support (https://github.com/jeremyevans/sequel)

## 0.11.4
- Make `without_instrumentation` thread safe

## 0.11.3
- Support Ruby 1.9 and up instead of 1.9.3 and up

## 0.11.2
- If APP_REVISION environment variable is set, send it with the log entry.

## 0.11.1
- Allow a custom request_class and params_method on  Rack instrumentation
- Loop through env methods instead of env
- Add HTTP_CLIENT_IP to env methods

## 0.11.0
- Improved inter process communication
- Retry sending data when the push api is not reachable
- Our own event handling to allow for more flexibility and reliability
  when using a threaded environment
- Resque officially supported!

## 0.10.6
- Add config option to skip session data

## 0.10.5
- Don't shutdown in `at_exit`
- Debug log about missing name in config

## 0.10.4
- Add REQUEST_URI and PATH_INFO to env params allowlist

## 0.10.3
- Shut down all operations when agent is not active
- Separately rescue OpenSSL::SSL::SSLError

## 0.10.2
- Bugfix in event payload sanitization

## 0.10.1
- Bugfix in event payload sanitization

## 0.10.0
- Remove ActiveSupport dependency
- Use vendored notifications if ActiveSupport is not present
- Update bundled CA certificates
- Fix issue where backtrace can be nil
- Use Appsignal.monitor_transaction to instrument and log errors for
  custom actions
- Add option to ignore a specific action

## 0.9.6
- Convert to primitives before sending through pipe

## 0.9.5
Yanked

## 0.9.4
- Log Rails and Sinatra version
- Resubscribe to notifications after fork

## 0.9.3
- Log if appsignal is not active for an environment

## 0.9.2
- Log Ruby version and platform on startup
- Log reason of shutting down agent

## 0.9.1
- Some debug logging tweaks

## 0.9.0
- Add option to override Capistrano revision
- Expanded deploy message in Capistrano
- Refactor of usage of Thread.local
- Net::HTTP instrumentation
- Capistrano 3 support

## 0.8.15
- Exception logging in agent thread

## 0.8.14
- Few tweaks in logging
- Clarify Appsignal::Transaction.complete! code

## 0.8.13
- Random sleep time before first transmission of queue

## 0.8.12
- Workaround for frozen string in Notification events
- Require ActiveSupport::Notifications to be sure it's available

## 0.8.11
- Skip enqueue, send_exception and add_exception if not active

## 0.8.10
- Bugfix: Don't pause agent when it's not active

## 0.8.9
Yanked

## 0.8.8
- Explicitly require securerandom

## 0.8.7
- Dup process action event to avoid threading issue
- Rescue failing inspects in param sanitizer
- Add option to pause instrumentation

## 0.8.6
- Resque support (beta)
- Support tags in Appsignal.send_exception
- Alias tag_request to tag_job, for background jobs
- Skip sanitization of env if env is nil
- Small bugfix in forking logic
- Don't send params if send_params is off in config
- Remove --repository option in CLI
- Name option in appsignal notify_of_deploy CLI
- Don't call to_hash on ENV
- Get error message in CLI when config is not active

## 0.8.5
- Don't require revision in CLI notify_of_deploy

## 0.8.4
- Skip session sanitize if not a http request
- Use appsignal_config in Capistrano as initial config

## 0.8.3
- Restart thread when we've been forked
- Only notify of deploy when active in capistrano
- Make sure env is a string in config

## 0.8.2
- Bugfix in Delayed Job integration
- appsignal prefix when logging to stdout
- Log to stdout on Shelly Cloud

## 0.8.1
- Fix in monitoring of queue times

## 0.8.0
- Support for background processors (Delayed Job and Sidekiq)

## 0.7.1
- Better support for forking webservers

## 0.7.0
- Mayor refactor and cleanup
- New easier onboarding process
- Support for Rack apps, including experimental Sinatra integration
- Monitor HTTP queue times
- Always log to stdout on Heroku

## 0.6.7
- Send HTTP_X_FORWARDED_FOR env var

## 0.6.6
- Add Appsignal.add_exception

## 0.6.5
- Fix bug where fast requests are tracked with wrong action

## 0.6.4
- More comprehensive debug logging

## 0.6.3
- Use a mutex around access to the aggregator
- Bugfix for accessing connection config in Rails 3.0
- Add Appsignal.tag_request
- Only warn if there are duplicate push keys

## 0.6.2
- Bugfix in backtrace cleaner usage for Rails 4

## 0.6.1
- Bugfix in Capistrano integration

## 0.6.0
- Support for Rails 4
- Data that's posted to AppSignal is now gzipped
- Add Appsignal.send_exception and Appsignal.listen_for_exception
- We now us the Rails backtrace cleaner

## 0.5.5
- Fix minor bug

## 0.5.4
- Debug option in config to get detailed logging

## 0.5.3
- Fix minor bug

## 0.5.2
- General improvements to the Rails generator
- Log to STDOUT if writing to log/appsignal.log is not possible (Heroku)
- Handle the last transactions before the rails process shuts down
- Require 'erb' to enable dynamic config
