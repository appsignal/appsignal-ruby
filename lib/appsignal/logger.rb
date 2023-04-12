# frozen_string_literal: true

require "logger"
require "set"

module Appsignal
  # Logger that flushes logs to the AppSignal logging service
  class Logger < ::Logger
    PLAINTEXT = 0
    LOGFMT = 1
    JSON = 2
    SEVERITY_MAP = {
      DEBUG => 2,
      INFO => 3,
      WARN => 5,
      ERROR => 6,
      FATAL => 7
    }.freeze

    # Create a new logger instance
    #
    # @param group Name of the group for this logger.
    # @param level Log level to filter with
    # @return [void]
    def initialize(group, level: INFO, format: PLAINTEXT)
      raise TypeError, "group must be a string" unless group.is_a? String

      @group = group
      @level = level
      @format = format
      @mutex = Mutex.new
    end

    # We support the various methods in the Ruby
    # logger class by supplying this method.
    # @api private
    def add(severity, message = nil, group = nil)
      severity ||= UNKNOWN
      return true if severity < level

      group = @group if group.nil?
      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          group = @group
        end
      end
      return if message.nil?

      message = formatter.call(severity, Time.now, group, message) if formatter

      Appsignal::Extension.log(
        group,
        SEVERITY_MAP.fetch(severity, 0),
        @format,
        message,
        Appsignal::Utils::Data.generate(appsignal_attributes)
      )
    end
    alias log add

    # Log a debug level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def debug(message = nil, attributes = {})
      return if level > DEBUG

      message = yield if message.nil? && block_given?
      return if message.nil?

      add_with_attributes(DEBUG, message, @group, attributes)
    end

    # Log an info level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def info(message = nil, attributes = {})
      return if level > INFO

      message = yield if message.nil? && block_given?
      return if message.nil?

      add_with_attributes(INFO, message, @group, attributes)
    end

    # Log a warn level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def warn(message = nil, attributes = {})
      return if level > WARN

      message = yield if message.nil? && block_given?
      return if message.nil?

      add_with_attributes(WARN, message, @group, attributes)
    end

    # Log an error level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def error(message = nil, attributes = {})
      return if level > ERROR

      message = yield if message.nil? && block_given?
      return if message.nil?

      add_with_attributes(ERROR, message, @group, attributes)
    end

    # Log a fatal level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def fatal(message = nil, attributes = {})
      return if level > FATAL

      message = yield if message.nil? && block_given?
      return if message.nil?

      add_with_attributes(FATAL, message, @group, attributes)
    end

    # When using ActiveSupport::TaggedLogging without the broadcast feature,
    # the passed logger is required to respond to the `silence` method.
    # In our case it behaves as the broadcast feature of the Rails logger, but
    # we don't have to check if the parent logger has the `silence` method defined
    # as our logger directly inherits from Ruby base logger.
    #
    # Links:
    # https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger.rb#L60-L76
    # https://github.com/rails/rails/blob/main/activesupport/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/active_support/logger_silence.rb
    def silence(_severity = ERROR, &block)
      block.call
    end

    private

    def add_with_attributes(severity, message, group, attributes)
      Thread.current[:appsignal_logger_attributes] = attributes
      add(severity, message, group)
    ensure
      Thread.current[:appsignal_logger_attributes] = nil
    end

    def appsignal_attributes
      Thread.current.fetch(:appsignal_logger_attributes, {})
    end
  end
end
