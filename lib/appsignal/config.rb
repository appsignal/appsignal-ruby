require 'erb'
require 'yaml'
require 'appsignal/careful_logger'

module Appsignal

  class Config
    include Appsignal::CarefulLogger

    DEFAULT_CONFIG = {
      :ignore_exceptions => [],
      :endpoint => 'https://push.appsignal.com/1',
      :slow_request_threshold => 200
    }.freeze

    attr_reader :configurations, :project_path, :env

    def initialize(project_path, env, logger=Appsignal.logger)
      @project_path = project_path
      @env = env.to_sym
      @logger = logger
      @configurations = {}
    end

    def load
      return unless load_configurations_from_disk
      return unless used_unique_api_keys
      return unless current_environment_present

      DEFAULT_CONFIG.merge(configurations[env])
    end

    protected

    def load_configurations_from_disk
      file = File.join(project_path, 'config', 'appsignal.yml')
      unless File.exists?(file)
        carefully_log_error "config not found at: '#{file}'"
        return false
      end
      @configurations = YAML.load(ERB.new(IO.read(file)).result)
      configurations.each { |k,v| v.symbolize_keys! }
      configurations.symbolize_keys!
      true
    end

    def used_unique_api_keys
      keys = configurations.each_value.map { |config| config[:api_key] }.compact
      if keys.uniq.count < keys.count
        carefully_log_error('Duplicate API keys found in appsignal.yml')
        false
      else
        true
      end
    end

    def current_environment_present
      return true if configurations[env].present?
      carefully_log_error "config for '#{env}' not found"
      false
    end
  end
end
