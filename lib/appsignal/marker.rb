require 'appsignal/integrations/capistrano/careful_logger'

module Appsignal
  class Marker
    include Appsignal::CarefulLogger

    attr_reader :marker_data, :config, :logger
    ACTION = 'markers'

    def initialize(marker_data, config, logger)
      @marker_data = marker_data
      @config = config
      @logger = logger
    end

    def transmit
      transmitter = Transmitter.new(ACTION, config)
      logger.info("Notifying Appsignal of deploy with: revision: #{marker_data[:revision]}, user: #{marker_data[:user]}")
      result = transmitter.transmit(marker_data)
      if result == '200'
        logger.info('Appsignal has been notified of this deploy!')
      else
        raise "#{result} at #{transmitter.uri}"
      end
    rescue Exception => e
      carefully_log_error(
        "Something went wrong while trying to notify Appsignal: #{e}"
      )
    end
  end
end
