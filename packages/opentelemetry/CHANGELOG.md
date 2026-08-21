# AppSignal OpenTelemetry gem Changelog

## 5.0.0.rc.1

_Published on 2026-08-21._

### Added

- Add the `appsignal-opentelemetry` gem. It installs the OpenTelemetry gems that AppSignal needs to run in collector mode. Add it alongside `appsignal` to opt into collector mode with a single gem instead of listing each OpenTelemetry gem yourself:

  ```ruby
  gem "appsignal"
  gem "appsignal-opentelemetry"
  ```

  Collector mode requires Ruby 3.1 or newer, so this gem does too. Its version stays in lockstep with the `appsignal` gem.

  (major [9b122f6f](https://github.com/appsignal/appsignal-ruby/commit/9b122f6fcd04dba1e6d1881cac50f29325a90fe4))

### Changed

- Update appsignal dependency to 5.0.0.rc.1. (patch)


