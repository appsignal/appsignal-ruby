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
    end

    # We support the various methods in the Ruby
    # logger class by supplying this method.
    # @api private
    def add(severity, message = nil, group = nil, attributes = {})
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
        Appsignal::Utils::Data.generate(attributes)
      )
    end
    alias log add

    # Log a debug level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def debug(message = nil, attributes = {})
      return if DEBUG < level
      message = yield if message.nil? && block_given?
      return if message.nil?
      add(DEBUG, message, @group, attributes)
    end

    # Log an info level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def info(message = nil, attributes = {})
      return if INFO < level
      message = yield if message.nil? && block_given?
      return if message.nil?
      add(INFO, message, @group, attributes)
    end

    # Log a warn level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def warn(message = nil, attributes = {})
      return if WARN < level
      message = yield if message.nil? && block_given?
      return if message.nil?
      add(WARN, message, @group, attributes)
    end

    # Log an error level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def error(message = nil, attributes = {})
      return if ERROR < level
      message = yield if message.nil? && block_given?
      return if message.nil?
      add(ERROR, message, @group, attributes)
    end

    # Log a fatal level message
    # @param message Mesage to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def fatal(message = nil, attributes = {})
      return if FATAL < level
      message = yield if message.nil? && block_given?
      return if message.nil?
      add(FATAL, message, @group, attributes)
    end
  end
end
