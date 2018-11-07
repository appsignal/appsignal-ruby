# frozen_string_literal: true

module Appsignal
  # Keeps track of formatters for types event that we can use to get
  # the title and body of an event. Formatters should inherit from this class
  # and implement a format(payload) method which returns an array with the title
  # and body.
  #
  # When implementing a formatter remember that it cannot keep separate state per
  # event, the same object will be called intermittently in a threaded environment.
  # So only keep global configuration as state and pass the payload around as an
  # argument if you need to use helper methods.
  #
  # @api private
  class EventFormatter
    class << self
      include Appsignal::Utils::DeprecationMessage

      def formatters
        @@formatters ||= {}
      end

      def deprecated_formatter_classes
        @@deprecated_formatter_classes ||= {}
      end

      def formatter_classes
        @@formatter_classes ||= {}
      end

      def register(name, formatter = nil)
        unless formatter
          register_deprecated_formatter(name)
          return
        end

        if registered?(name, formatter)
          logger.warn(
            "Formatter for '#{name}' already registered, not registering "\
            "'#{formatter.name}'"
          )
          return
        end

        initialize_formatter name, formatter
      end

      def initialize_deprecated_formatters
        deprecated_formatter_classes.each do |name, formatter|
          register(name, formatter)
        end
      end

      def unregister(name, formatter = self)
        return unless formatter_classes[name] == formatter

        formatter_classes.delete(name)
        formatters.delete(name)
      end

      def registered?(name, klass = nil)
        if klass
          formatter_classes[name] == klass
        else
          formatter_classes.include?(name)
        end
      end

      def format(name, payload)
        formatter = formatters[name]
        formatter.format(payload) unless formatter.nil?
      end

      private

      def initialize_formatter(name, formatter)
        format_method = formatter.instance_method(:format)
        if format_method && format_method.arity == 1
          formatter_classes[name] = formatter
          formatters[name] = formatter.new
        else
          raise "#{formatter} does not have a format(payload) method"
        end
      rescue => ex
        formatter_classes.delete(name)
        formatters.delete(name)
        logger.warn("'#{ex.message}' when initializing #{name} event formatter")
      end

      def register_deprecated_formatter(name)
        deprecation_message \
          "Formatter for '#{name}' is using a deprecated registration " \
          "method. This event formatter will not be loaded. " \
          "Please update the formatter according to the documentation at: " \
          "https://docs.appsignal.com/ruby/instrumentation/event-formatters.html",
          logger

        deprecated_formatter_classes[name] = self
      end

      def logger
        Appsignal.logger
      end
    end

    # @api public
    DEFAULT = 0
    # @api public
    SQL_BODY_FORMAT = 1
  end
end

Dir.glob(File.expand_path("../event_formatter/**/*.rb", __FILE__)).each do |file|
  require file
end
