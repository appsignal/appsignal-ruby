# frozen_string_literal: true

require "yaml"

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
        @agent_config ||= YAML.load(
          File.read(File.join(File.dirname(__FILE__), "../../ext/agent.yml"))
        )
      end

      def agent_version
        agent_config["version"]
      end

      # Do nothing if the extension methods are not loaded
      #
      # Disabled in testing so we can make sure that we don't miss a extension
      # function implementation.
      def method_missing(m, *args, &block)
        super if Appsignal.testing?
      end
    end

    if Appsignal::System.jruby?
      extend Appsignal::Extension::Jruby

      # Reassign Transaction class for JRuby extension usage.
      #
      # Makes sure the generated docs aren't always overwritten with the JRuby
      # version.
      Transaction = Jruby::Transaction
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
  end
end
