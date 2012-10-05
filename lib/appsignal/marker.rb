module Appsignal
  class Marker

    attr_reader :marker_data, :config, :logger
    ACTION = 'markers'

    def initialize(marker_data, rails_env, logger)
      @marker_data = marker_data
      @config = Appsignal::Config.new(Dir.pwd, rails_env).load
      @logger = logger
    end

    def transmit
      begin
        transmitter = Transmitter.new(
          @config[:endpoint], ACTION, @config[:api_key]
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
  end
end
