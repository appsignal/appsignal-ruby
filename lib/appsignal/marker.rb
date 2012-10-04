module Appsignal
  class Marker

    attr_reader :marker_data, :rails_env, :config, :logger
    ACTION = 'markers'

    def initialize(marker_data, rails_env, logger)
      @marker_data = marker_data
      @rails_env = rails_env
      @config = config
      @logger = logger
    end

    def transmit
      begin
        transmitter = Transmitter.new(
          @config['endpoint'], ACTION, @config['api_key']
        )
        @logger.info "Notifying Appsignal of deploy..."
        result = transmitter.transmit(:marker_data => marker_data)
        if result == '200'
          @logger.info "Appsignal has been notified of this deploy!"
        else
          raise
        end
      rescue
        @logger.info "Something went wrong while trying to notify Appsignal!"
      end
    end

    def config
      file = File.join(Dir.pwd, "config/appsignal.yml")
      unless File.exists?(file)
        raise ArgumentError, "config not found at: #{file}"
      end
      config = YAML.load_file(file)[@rails_env]
      raise ArgumentError,
        "config for '#{@rails_env}' environment not found" unless config
      config
    end
  end
end
