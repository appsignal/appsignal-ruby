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
    def initialize(group, level: INFO, format: PLAINTEXT, attributes: {}, tags: [])
      raise TypeError, "group must be a string" unless group.is_a? String

      @group = group
      @level = level
      @format = format
      @mutex = Mutex.new
      @default_attributes = attributes
      @appsignal_attributes = {}
      @tags = tags
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

      if @tags.any?
        formatted_tags = @tags.map { |tag| "[#{tag}]" }
        message = "#{formatted_tags.join(" ")} #{message}"
      end

      message = formatter.call(severity, Time.now, group, message) if formatter

      unless message.is_a?(String)
        Appsignal.internal_logger.warn(
          "Logger message was ignored, because it was not a String: #{message.inspect}"
        )
        return
      end

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

    # Listen to ActiveSupport tagged logging tags set with `Rails.logger.tagged`.
    def tagged(*tags)
      # Depending on the Rails version, the tags can be passed as an array or
      # as separate arguments. Flatten the tags argument array to deal with them
      # indistinctly.
      tags = tags.flatten

      # If called without a block, return a new logger that always logs with the
      # given set of tags.
      return with_tags(tags) unless block_given?

      # If called with a block, modify the current logger to log with the given
      # set of tags for the duration of the block.
      @tags.append(*tags)
      begin
        yield self
      ensure
        @tags.pop(tags.length)
      end
    end

    # Listen to ActiveSupport tagged logging tags set with `Rails.config.log_tags`.
    def push_tags(*tags)
      # Depending on the Rails version, the tags can be passed as an array or
      # as separate arguments. Flatten the tags argument array to deal with them
      # indistinctly.
      tags = tags.flatten
      @tags.append(*tags)
    end

    # Remove a set of ActiveSupport tagged logging tags set with `Rails.config.log_tags`.
    def pop_tags(count = 1)
      @tags.pop(count)
    end

    # Remove all ActiveSupport tagged logging tags set with `Rails.config.log_tags`.
    def clear_tags!
      @tags.clear
    end

    # When using ActiveSupport::TaggedLogging without the broadcast feature,
    # the passed logger is required to respond to the `silence` method.
    # In our case it behaves as the broadcast feature of the Rails logger, but
    # we don't have to check if the parent logger has the `silence` method defined
    # as our logger directly inherits from Ruby base logger.
    #
    # Links:
    #
    # - https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger.rb#L60-L76
    # - https://github.com/rails/rails/blob/e11ebc04cfbe41c06cdfb70ee5a9fdbbd98bb263/activesupport/lib/active_support/logger_silence.rb
    def silence(_severity = ERROR, &block)
      block.call
    end

    private

    def with_tags(tags)
      Logger.new(
        @group,
        :level => @level,
        :format => @format,
        :attributes => @default_attributes,
        :tags => @tags + tags
      )
    end

    attr_reader :default_attributes, :appsignal_attributes

    def add_with_attributes(severity, message, group, attributes)
      @appsignal_attributes = default_attributes.merge(attributes)
      add(severity, message, group)
    ensure
      @appsignal_attributes = {}
    end
  end
end
