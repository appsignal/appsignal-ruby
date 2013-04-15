require 'appsignal/careful_logger'

module Appsignal

  class Config
    include Appsignal::CarefulLogger

    DEFAULT_CONFIG = {
      :ignore_exceptions => [],
      :endpoint => 'https://push.appsignal.com/1',
      :slow_request_threshold => 200
    }.freeze

    attr_accessor :project_path, :env

    def initialize(project_path, env, logger=Appsignal.logger)
      @project_path = project_path
      @env = env
      @logger = logger
    end

    def load
      file = File.join(@project_path, 'config', 'appsignal.yml')
      unless File.exists?(file)
        carefully_log_error "config not found at: #{file}"
        return
      end

      config = YAML.load(ERB.new(IO.read(file)).result)[@env]
      unless config
        carefully_log_error "config for '#{@env}' not found"
        return
      end

      DEFAULT_CONFIG.merge(config.symbolize_keys)
    end

  end

end
