# frozen_string_literal: true

require "appsignal/opentelemetry/attributes"

module Appsignal
  class Logger < ::Logger
    # @!visibility private
    #
    # Routes Appsignal::Logger emits through the OpenTelemetry logs SDK
    # using the logger provider configured at `Appsignal.start` time when
    # collector mode is active.
    #
    # Each emit attaches two well-known attributes that the AppSignal
    # collector consumes:
    #
    # - `appsignal.group` — overrides the collector's default
    #   `service.name`-based grouping with the logger's `group` argument.
    # - `appsignal.format` — the lowercase parse-format name
    #   (`plaintext`/`logfmt`/`json`/`autodetect`) the processor uses to
    #   extract structured attributes from the message body.
    module OpenTelemetryBackend
      # Maps Ruby `::Logger` severities to OTel SeverityNumber + the
      # human-readable severity text.
      OTEL_SEVERITY_MAP = {
        ::Logger::DEBUG => [5, "DEBUG"],
        ::Logger::INFO => [9, "INFO"],
        ::Logger::WARN => [13, "WARN"],
        ::Logger::ERROR => [17, "ERROR"],
        ::Logger::FATAL => [21, "FATAL"]
      }.freeze

      # Maps the integer parse-format flag on `Appsignal::Logger` to the
      # lowercase string the AppSignal collector and processor share.
      FORMAT_NAMES = {
        Appsignal::Logger::PLAINTEXT => "plaintext",
        Appsignal::Logger::LOGFMT => "logfmt",
        Appsignal::Logger::JSON => "json",
        Appsignal::Logger::AUTODETECT => "autodetect"
      }.freeze

      MUTEX = Mutex.new

      class << self
        def emit(group, severity, format, message, attributes)
          number, text = OTEL_SEVERITY_MAP.fetch(severity, [0, nil])
          otel_attributes = Appsignal::OpenTelemetry::Attributes.format(attributes)
          otel_attributes["appsignal.group"] = group.to_s
          otel_attributes["appsignal.format"] = FORMAT_NAMES.fetch(format, "autodetect")
          logger.on_emit(
            :severity_number => number,
            :severity_text => text,
            :body => message,
            :attributes => otel_attributes
          )
        end

        # @!visibility private
        #
        # Test-only. Drops the cached logger so the next call re-resolves
        # `OpenTelemetry.logger_provider`.
        def reset!
          MUTEX.synchronize { @logger = nil }
        end

        private

        # Double-checked locking: read the cached logger without the
        # mutex on the hot path, take the lock and re-check only on the
        # first call.
        def logger
          @logger || MUTEX.synchronize do
            @logger ||= ::OpenTelemetry.logger_provider.logger(:name => "appsignal-logger")
          end
        end
      end
    end
  end
end
