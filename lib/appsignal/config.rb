module Appsignal
  class Config
    attr_accessor :rails_env, :root_path

    def initialize(rails_env)
      @rails_env = rails_env
      @root_path = Rails.root
    end

    def load
      file = File.join(@root_path, "config/appsignal.yml")
      raise ArgumentError,
        "config not found at: #{file}" unless File.exists?(file)

      config = YAML.load_file(file)[@rails_env]
      raise ArgumentError,
        "config for '#{@rails_env}' environment not found" unless config

      config = {:ignore_exceptions => [],
        :endpoint => 'https://push.appsignal.com/api/1',
        :slow_request_threshold => 200
      }.merge(config.symbolize_keys)
    end
  end
end
