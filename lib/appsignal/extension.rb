require "yaml"

begin
  require "appsignal_extension"
  Appsignal.extension_loaded = true
rescue LoadError => err
  Appsignal.logger.error(
    "Failed to load extension (#{err}), please check the install.log file in " \
    "the ext directory of the gem and e-mail us at support@appsignal.com"
  )
  Appsignal.extension_loaded = false
end

module Appsignal
  # @api private
  class Extension
    class << self
      def agent_config
        @agent_config ||= YAML.safe_load(
          File.read(File.join(File.dirname(__FILE__), "../../ext/agent.yml")),
          [],
          [],
          true
        )
      end

      def agent_version
        agent_config["version"]
      end

      def method_missing(m, *args, &block)
        # Do nothing if the extension methods are not loaded
      end
    end

    class Data
      def inspect
        "#<#{self.class.name}:#{object_id} #{self}>"
      end
    end
  end
end
