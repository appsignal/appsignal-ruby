module Appsignal
  class AuthCheck
    delegate :uri, :to => :transmitter
    attr_reader :config
    attr_accessor :transmitter
    ACTION = 'auth'

    def initialize(environment)
      @config = Appsignal::Config.new(Rails.root, environment).load
    end

    def perform
      self.transmitter = Appsignal::Transmitter.new(
        @config[:endpoint], ACTION, @config[:api_key]
      )
      transmitter.transmit
    end
  end
end
