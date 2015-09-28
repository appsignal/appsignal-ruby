module Appsignal
  module ExtensionLoader
    def self.agent_config
      @agent_config ||= YAML.load(
        File.read(File.join(File.dirname(__FILE__), '../../ext/agent.yml'))
      )
    end

    def self.arch
      "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"
    end

    def self.lib_path
      File.join(
        File.dirname(__FILE__),
        '../../ext/',
        agent_config[:triples][arch][:lib_filename]
      )
    end

    def self.agent_version
      agent_config[:version]
    end

    def self.failed(exception)
      Appsignal.logger.error(
        "Failed to load extension (#{exception}), please check the install.log file in " \
        "the ext directory of the gem and e-mail us at support@appsignal.com"
      )
      Appsignal.extension_loaded = false
    end

    def self.load_extension
      begin
        require 'fiddle'
        begin
          Fiddle.dlopen(lib_path)
        rescue => ex
          failed(ex)
          return
        end
      rescue LoadError
        # This is Ruby 2.1 or older
        require 'dl'
        begin
          DL.dlopen(lib_path)
        rescue => ex
          failed(ex)
          return
        end
      end

      require 'appsignal_extension'

      Appsignal.extension_loaded = true
    end
  end
end

Appsignal::ExtensionLoader.load_extension
