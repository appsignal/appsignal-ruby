# frozen_string_literal: true

require "logger"
require "set"

module Appsignal
  # Logger that flushes logs to the AppSignal logging service.
  #
  # @see https://docs.appsignal.com/logging/platforms/integrations/ruby.html
  #   AppSignal Ruby logging documentation.
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

    attr_reader :level

    # Create a new logger instance
    #
    # @param group Name of the group for this logger.
    # @param level Minimum log level to report. Log lines below this level will be ignored.
    # @param format Format to use to parse log line attributes.
    # @param attributes Default attributes for all log lines.
    # @return [void]
    def initialize(group, level: INFO, format: PLAINTEXT, attributes: {})
      raise TypeError, "group must be a string" unless group.is_a? String

      @group = group
      @level = level
      @format = format
      @mutex = Mutex.new
      @default_attributes = attributes
      @appsignal_attributes = {}
      @loggers = []
    end

    # When a formatter is set on the logger (e.g. when wrapping the logger in
    # `ActiveSupport::TaggedLogging`) we want to set that formatter on all the
    # loggers that are being broadcasted to.
    def formatter=(formatter)
      super
      @loggers.each { |logger| logger.formatter = formatter }
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
          message = group
          group = @group
        end
      end
      return if message.nil?

      @loggers.each do |logger|
        logger.add(severity, message, group)
      rescue
        nil
      end

      unless message.is_a?(String)
        Appsignal.internal_logger.warn(
          "Logger message was ignored, because it was not a String: #{message.inspect}"
        )
        return
      end

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
    # @param message Message to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def debug(message = nil, attributes = {})
      return if level > DEBUG

      message = yield if message.nil? && block_given?
      return if message.nil?

      add_with_attributes(DEBUG, message, @group, attributes)
    end

    # Log an info level message
    # @param message Message to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def info(message = nil, attributes = {})
      return if level > INFO

      message = yield if message.nil? && block_given?
      return if message.nil?

      add_with_attributes(INFO, message, @group, attributes)
    end

    # Log a warn level message
    # @param message Message to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def warn(message = nil, attributes = {})
      return if level > WARN

      message = yield if message.nil? && block_given?
      return if message.nil?

      add_with_attributes(WARN, message, @group, attributes)
    end

    # Log an error level message
    # @param message Message to log
    # @param attributes Attributes to tag the log with
    # @return [void]
    def error(message = nil, attributes = {})
      return if level > ERROR

      message = yield if message.nil? && block_given?
      return if message.nil?

      message = "#{message.class}: #{message.message}" if message.is_a?(Exception)

      add_with_attributes(ERROR, message, @group, attributes)
    end

    # Log a fatal level message
    # @param message Message to log
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
    #
    # Reference links:
    #
    # - https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger.rb#L60-L76
    # - https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger_silence.rb
    def silence(severity = ERROR, &block)
      previous_level = @level
      @level = severity
      block.call(self)
    ensure
      @level = previous_level
    end

    def broadcast_to(logger)
      @loggers << logger
    end

    private

    attr_reader :default_attributes, :appsignal_attributes

    def add_with_attributes(severity, message, group, attributes)
      @appsignal_attributes = default_attributes.merge(attributes)
      add(severity, message, group)
    ensure
      @appsignal_attributes = {}
    end
  end
end
