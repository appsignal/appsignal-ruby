module Appsignal
  class AuthCheck
    ACTION = 'auth'.freeze

    attr_reader :environment, :logger
    attr_accessor :transmitter
    delegate :uri, :to => :transmitter

    def initialize(*args)
      @environment = args.shift
      options = args.empty? ? {} : args.last
      @config = options[:config]
      @logger = options[:logger]
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
  end
end
