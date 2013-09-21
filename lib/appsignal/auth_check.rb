module Appsignal
  class AuthCheck
    ACTION = 'auth'.freeze

    attr_reader :environment, :logger
    attr_accessor :transmitter

    def initialize(*args)
      @environment = args.shift
      options = args.empty? ? {} : args.last
      @config = options[:config]
      @logger = options[:logger]
    end

    def uri
      transmitter.uri
    end

    def config
      @config ||= Appsignal::Config.new(Rails.root, environment, logger).load
    end

    def perform
      self.transmitter = Appsignal::Transmitter.new(
        config[:endpoint], ACTION, config[:api_key]
      )
      transmitter.transmit({})
    end

    def perform_with_result
      begin
        status = perform
        case status
        when '200'
          result = 'AppSignal has confirmed authorization!'
        when '401'
          result = 'API key not valid with AppSignal...'
        else
          result = 'Could not confirm authorization: '\
            "#{status.nil? ? 'nil' : status}"
        end
        [status, result]
      rescue Exception => e
        result = 'Something went wrong while trying to '\
          "authenticate with AppSignal: #{e}"
        [nil, result]
      end
    end
  end
end
