module Appsignal
  class AuthCheck
    ACTION = 'auth'.freeze

    attr_reader :config, :logger

    def initialize(config, logger=Appsignal.logger)
      @config = config
      @logger = logger
    end

    def perform
      Appsignal::Transmitter.new(ACTION, config).transmit({})
    end

    def perform_with_result
      begin
        status = perform
        result =
          case status
          when "200"
            "AppSignal has confirmed authorization!"
          when "401"
            "API key not valid with AppSignal..."
          else
            "Could not confirm authorization: " \
              "#{status.nil? ? 'nil' : status}"
          end
        [status, result]
      rescue => e
        result = 'Something went wrong while trying to '\
                 "authenticate with AppSignal: #{e}"
        [nil, result]
      end
    end
  end
end
