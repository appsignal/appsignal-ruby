# AppSignal for Ruby gem Changelog

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
- Handle out of range numbers in queue lenght and metrics api

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
- Rescue more expections in json generation

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
- Better handling for non-utf8 convertable strings
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
- Explicitely require securerandom

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
