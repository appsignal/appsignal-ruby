module Appsignal
  class Config
    attr_accessor :root_path, :rails_env

    def initialize(root_path, rails_env)
      @root_path = root_path
      @rails_env = rails_env
    end

    def load
      file = File.join(@root_path, 'config/appsignal.yml')

      unless File.exists?(file)
        Appsignal.logger.error "config not found at: #{file}"
        return
      end

      config = YAML.load_file(file)[@rails_env]

      unless config
        Appsignal.logger.error "config for '#{@rails_env}' not found"
        return
      end

      config = {:ignore_exceptions => [],
        :endpoint => 'https://push.appsignal.com/1',
        :slow_request_threshold => 200
      }.merge(config.symbolize_keys)
    end
  end
end
