module Appsignal
  class Config
    attr_accessor :root_path, :rails_env

    def initialize(root_path, rails_env)
      @root_path = root_path
      @rails_env = rails_env
    end

    def load
      file = File.join(@root_path, 'config/appsignal.yml')
      raise ArgumentError,
        "config not found at: #{file}" unless File.exists?(file)

      config = YAML.load_file(file)[@rails_env]
      raise ArgumentError,
        "config for '#{@rails_env}' environment not found" unless config

      config = {:ignore_exceptions => [],
        :endpoint => 'https://push.appsignal.com/1',
        :slow_request_threshold => 200
      }.merge(config.symbolize_keys)
    end
  end
end
