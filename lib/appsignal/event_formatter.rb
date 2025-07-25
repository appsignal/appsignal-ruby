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
  class EventFormatter
    class << self
      # @!visibility private
      def formatters
        @formatters ||= {}
      end

      # @!visibility private
      def formatter_classes
        @formatter_classes ||= {}
      end

      # Registers an event formatter for a specific event name.
      #
      # @param name [String, Symbol] The name of the event to register the formatter for.
      # @param formatter [Class] The formatter class that implements the `format(payload)` method.
      # @return [void]
      #
      # @example Register a custom formatter
      #   class CustomFormatter < Appsignal::EventFormatter
      #     def format(payload)
      #       ["Custom event", payload[:body]]
      #     end
      #   end
      #
      #   Appsignal::EventFormatter.register("my.event", CustomFormatter)
      #
      # @see #unregister
      # @see #registered?
      def register(name, formatter = nil)
        if registered?(name, formatter)
          logger.warn(
            "Formatter for '#{name}' already registered, not registering " \
              "'#{formatter.name}'"
          )
          return
        end

        initialize_formatter name, formatter
      end

      # Unregisters an event formatter for a specific event name.
      #
      # @param name [String, Symbol] The name of the event to unregister the formatter for.
      # @param formatter [Class] The formatter class to unregister. Defaults to `self`.
      # @return [void]
      #
      # @example Unregister a custom formatter
      #   Appsignal::EventFormatter.unregister("my.event", CustomFormatter)
      #
      # @see #register
      # @see #registered?
      def unregister(name, formatter = self)
        return unless formatter_classes[name] == formatter

        formatter_classes.delete(name)
        formatters.delete(name)
      end

      # Checks if an event formatter is registered for a specific event name.
      #
      # @param name [String, Symbol] The name of the event to check.
      # @param klass [Class, nil] The specific formatter class to check for. Optional.
      # @return [Boolean] true if a formatter is registered, false otherwise.
      #
      # @see #register
      # @see #unregister
      def registered?(name, klass = nil)
        if klass
          formatter_classes[name] == klass
        else
          formatter_classes.include?(name)
        end
      end

      # @!visibility private
      def format(name, payload)
        formatter = formatters[name]
        formatter&.format(payload)
      end

      private

      def initialize_formatter(name, formatter)
        format_method = formatter.instance_method(:format)
        if !format_method || format_method.arity != 1
          raise "#{formatter} does not have a format(payload) method"
        end

        formatter_classes[name] = formatter
        formatters[name] = formatter.new
      rescue => ex
        formatter_classes.delete(name)
        formatters.delete(name)
        logger.error("'#{ex.message}' when initializing #{name} event formatter")
      end

      def logger
        Appsignal.internal_logger
      end
    end

    # @return [Integer]
    # @api public
    DEFAULT = 0
    # @return [Integer]
    # @api public
    SQL_BODY_FORMAT = 1
  end
end

Dir.glob(File.expand_path("event_formatter/**/*.rb", __dir__)).sort.each do |file|
  require file
end
