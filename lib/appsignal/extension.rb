require 'yaml'

begin
  require 'appsignal_extension'
  Appsignal.extension_loaded = true
rescue LoadError => err
  Appsignal.logger.error(
    "Failed to load extension (#{err}), please check the install.log file in " \
    "the ext directory of the gem and e-mail us at support@appsignal.com"
  )
  Appsignal.extension_loaded = false
end

module Appsignal
  class Extension
    def self.agent_config
      @agent_config ||= YAML.load(
        File.read(File.join(File.dirname(__FILE__), '../../ext/agent.yml'))
      )
    end

    def self.agent_version
      agent_config[:version]
    end
  end
end
