module Appsignal
  class AuthCheck
    delegate :uri, :to => :transmitter
    attr_reader :config
    attr_accessor :transmitter
    ACTION = 'auth'

    def initialize
      @config = Appsignal::Config.new(Rails.root, 'production').load
    end

    def perform
      self.transmitter = Appsignal::Transmitter.new(
        @config[:endpoint], ACTION, @config[:api_key]
      )
      transmitter.transmit
    end
  end
end
