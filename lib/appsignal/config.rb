module Appsignal

  class Config
    DEFAULT_CONFIG = {
      :ignore_exceptions => [],
      :endpoint => 'https://push.appsignal.com/1',
      :slow_request_threshold => 200
    }.freeze

    attr_accessor :root_path, :rails_env

    def initialize(root_path, rails_env, logger=Appsignal.logger)
      @root_path = root_path
      @rails_env = rails_env
      @logger = logger
    end

    def load
      file = File.join(@root_path, 'config/appsignal.yml')
      unless File.exists?(file)
        @logger.error "config not found at: #{file}"
        return
      end

      config = YAML.load_file(file)[@rails_env]
      unless config
        @logger.error "config for '#{@rails_env}' not found"
        return
      end

      DEFAULT_CONFIG.merge(config.symbolize_keys)
    end

  end

end
