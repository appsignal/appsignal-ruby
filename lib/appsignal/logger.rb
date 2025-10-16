# frozen_string_literal: true

require "logger"
require "set"

module Appsignal
  # Logger that flushes logs to the AppSignal logging service.
  #
  # @see https://docs.appsignal.com/logging/platforms/integrations/ruby.html
  #   AppSignal Ruby logging documentation.
  class Logger < ::Logger
    # A wrapper for a block that ensures it is only called once.
    # If called again, it will return the result of the first call.
    # This is useful for ensuring that a block is not executed multiple
    # times when it is broadcasted to multiple loggers.
    #
    # @!visibility private
    class BlockOnce
      def initialize(&block)
        @block = block
        @called = false
        @success = nil
        @result = nil
        @error = nil
      end

      def call(*args, **kwargs)
        if @called
          return @result if @success

          raise @error
        end

        @called = true
        @result = @block.call(*args, **kwargs)
        @success = true
        @result
      rescue StandardError => e
        @success = false
        @error = e
        raise @error
      end

      def to_proc
        method(:call).to_proc
      end
    end

    # @!visibility private
    PLAINTEXT = 0
    # @!visibility private
    LOGFMT = 1
    # @!visibility private
    JSON = 2
    # @!visibility private
    AUTODETECT = 3
    # @!visibility private
    SEVERITY_MAP = {
      DEBUG => 2,
      INFO => 3,
      WARN => 5,
      ERROR => 6,
      FATAL => 7
    }.freeze

    # Logging severity threshold
    # @return [Integer]
    attr_reader :level

    # Create a new logger instance
    #
    # @param group [String] Name of the group for this logger.
    # @param level [Integer] Minimum log level to report. Log lines below this
    #   level will be ignored.
    # @param format [Integer] Format to use to parse log line attributes.
    # @param attributes [Hash<String, String>] Default attributes for all log lines.
    # @return [void]
    def initialize(group, level: INFO, format: AUTODETECT, attributes: {})
      raise TypeError, "group must be a string" unless group.is_a? String

      @group = group
      @level = level
      @silenced = false
      @format = format
      @mutex = Mutex.new
      @default_attributes = attributes
      @appsignal_attributes = attributes
      @loggers = []
    end

    # Sets the formatter for this logger and all broadcasted loggers.
    # @param formatter [Proc] The formatter to use for log messages.
    # @return [Proc]
    def formatter=(formatter)
      super
      @loggers.each do |logger|
        logger.formatter = formatter if logger.respond_to?(:formatter=)
      end
    end

    # We support the various methods in the Ruby
    # logger class by supplying this method.
    # @!visibility private
    def add(severity, message = nil, group = nil, &block) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      # If we do not need to broadcast to any loggers and the severity is
      # below the log level, we can return early.
      severity ||= UNKNOWN
      return true if severity < level && @loggers.empty?

      # If the logger is silenced, we do not log *or broadcast* messages
      # below the log level.
      return true if @silenced && severity < @level

      # Ensure that the block is only run once, even if several loggers
      # are being broadcasted to.
      block = BlockOnce.new(&block) unless block.nil?

      # If the group is not set, we use the default group.
      group = @group if group.nil?

      did_not_log = true

      @loggers.each do |logger|
        # Loggers should return true if they did *not* log the message.
        # If any of the broadcasted loggers logs the message, that counts
        # as having logged the message.
        did_not_log &&= logger.add(severity, message, group, &block)
      rescue
        nil
      end

      # If the severity is below the log level, we do not log the message.
      return did_not_log if severity < level

      message = block.call if block && message.nil?

      return if message.nil?

      if message.is_a?(Exception)
        message = "#{message.class}: #{message.message} (#{message.backtrace[0]})"
      end

      message = formatter.call(severity, Time.now, group, message) if formatter

      Appsignal::Extension.log(
        group,
        SEVERITY_MAP.fetch(severity, 0),
        @format,
        message.to_s,
        Appsignal::Utils::Data.generate(appsignal_attributes)
      )

      false
    end
    alias log add

    # Log a debug level message
    # @param message [String] Message to log
    # @param attributes [Hash<String, Object>] Attributes to tag the log with
    # @return [void]
    def debug(message = nil, attributes = {}, &block)
      add_with_attributes(DEBUG, message, @group, attributes, &block)
    end

    # Log an info level message
    # @param message [String] Message to log
    # @param attributes [Hash<String, Object>] Attributes to tag the log with
    # @return [void]
    def info(message = nil, attributes = {}, &block)
      add_with_attributes(INFO, message, @group, attributes, &block)
    end

    # Log a warn level message
    # @param message [String] Message to log
    # @param attributes [Hash<String, Object>] Attributes to tag the log with
    # @return [void]
    def warn(message = nil, attributes = {}, &block)
      add_with_attributes(WARN, message, @group, attributes, &block)
    end

    # Log an error level message
    # @param message [String, Exception] Message to log
    # @param attributes [Hash<String, Object>] Attributes to tag the log with
    # @return [void]
    def error(message = nil, attributes = {}, &block)
      add_with_attributes(ERROR, message, @group, attributes, &block)
    end

    # Log a fatal level message
    # @param message [String, Exception] Message to log
    # @param attributes [Hash<String, Object>] Attributes to tag the log with
    # @return [void]
    def fatal(message = nil, attributes = {}, &block)
      add_with_attributes(FATAL, message, @group, attributes, &block)
    end

    # Log an info level message
    #
    # Returns the number of characters written.
    #
    # @param message [String] Message to log
    # @return [Integer]
    def <<(message)
      info(message)
      message.length
    end

    # Temporarily silences the logger to a specified level while executing a block.
    #
    # When using ActiveSupport::TaggedLogging without the broadcast feature,
    # the passed logger is required to respond to the `silence` method.
    #
    # Reference links:
    #
    # - https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger.rb#L60-L76
    # - https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger_silence.rb
    #
    # @param severity [Integer] The minimum severity level to log during the block.
    # @return [Object] The return value of the block.
    def silence(severity = ERROR, &block)
      previous_level = @level
      @level = severity
      @silenced = true
      block.call(self)
    ensure
      @level = previous_level
      @silenced = false
    end

    # Adds a logger to broadcast log messages to.
    # @param logger [Logger] The logger to add to the broadcast list.
    # @return [Array<Logger>]
    def broadcast_to(logger)
      @loggers << logger
    end

    private

    attr_reader :default_attributes, :appsignal_attributes

    def add_with_attributes(severity, message, group, attributes, &block)
      @appsignal_attributes = default_attributes.merge(attributes)
      add(severity, message, group, &block)
    ensure
      @appsignal_attributes = default_attributes
    end
  end
end
