# frozen_string_literal: true

begin
  if Appsignal::System.jruby?
    require "appsignal/extension/jruby"
    # {Appsignal.extension_loaded} is set in the JRuby extension file
  else
    require "appsignal_extension"
    Appsignal.extension_loaded = true
  end
rescue LoadError => error
  error_message = "ERROR: AppSignal failed to load extension. " \
    "Please run `appsignal diagnose` and email us at support@appsignal.com\n" \
    "#{error.class}: #{error.message}"
  Appsignal.logger.error(error_message)
  Kernel.warn error_message
  Appsignal.extension_loaded = false
end

module Appsignal
  # @api private
  class Extension
    class << self
      def agent_config
        require_relative "../../ext/agent"
        ::APPSIGNAL_AGENT_CONFIG
      end

      def agent_version
        agent_config["version"]
      end

      # Do nothing if the extension methods are not loaded
      #
      # Disabled in testing so we can make sure that we don't miss a extension
      # function implementation.
      def method_missing(_method, *args, &block)
        super if Appsignal.testing?
      end

      unless Appsignal.extension_loaded?
        def data_map_new
          Appsignal::Extension::MockData.new
        end

        def data_array_new
          Appsignal::Extension::MockData.new
        end
      end
    end

    if Appsignal::System.jruby?
      extend Appsignal::Extension::Jruby

      # Reassign Transaction class for JRuby extension usage.
      #
      # Makes sure the generated docs aren't always overwritten with the JRuby
      # version.
      Transaction = Jruby::Transaction
      # Reassign Span class for JRuby extension usage.
      #
      # Makes sure the generated docs aren't always overwritten with the JRuby
      # version.
      Span = Jruby::Span
      # Reassign Data class for JRuby extension usage.
      #
      # Makes sure the generated docs aren't always overwritten with the JRuby
      # version.
      Data = Jruby::Data
    end

    class Data
      def inspect
        "#<#{self.class.name}:#{object_id} #{self}>"
      end
    end

    # Mock of the {Data} class. This mock is used when the extension cannot be
    # loaded. This mock listens to all method calls and does nothing, and
    # prevents NoMethodErrors from being raised.
    #
    # Disabled in testing so we can make sure that we don't miss an extension
    # function implementation.
    #
    # This class inherits from the {Data} class so that it passes type checks.
    class MockData < Data
      def initialize(*_args)
        # JRuby extension requirement, as it sends a pointer to the Data object
        # when creating it
      end

      def method_missing(_method, *_args, &_block)
        super if Appsignal.testing?
      end

      def to_s
        "{}"
      end
    end

    # Mock of the {Transaction} class. This mock is used when the extension
    # cannot be loaded. This mock listens to all method calls and does nothing,
    # and prevents NoMethodErrors from being raised.
    #
    # Disabled in testing so we can make sure that we don't miss an extension
    # function implementation.
    class MockTransaction
      def initialize(*_args)
        # JRuby extension requirement, as it sends a pointer to the Transaction
        # object when creating it
      end

      def method_missing(_method, *_args, &_block)
        super if Appsignal.testing?
      end
    end
  end
end
