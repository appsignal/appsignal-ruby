raise 'This appsignal gem only works with rails' unless defined?(Rails)

module Appsignal
  class << self
    attr_accessor :subscriber, :event_payload_sanitizer

    def active
      config && config[:active] == true
    end

    def logger
      @logger ||= Logger.new("#{Rails.root}/log/appsignal.log")
    end

    def transactions
      @transactions ||= {}
    end

    def agent
      @agent ||= Appsignal::Agent.new
    end

    def config
      @config ||= Appsignal::Config.new(Rails.root, Rails.env).load
    end

    def event_payload_sanitizer
      @event_payload_sanitizer ||= proc { |event| event.payload }
    end
  end
end

require 'appsignal/cli'
require 'appsignal/config'
require 'appsignal/transmitter'
require 'appsignal/agent'
require 'appsignal/marker'
require 'appsignal/middleware'
require 'appsignal/transaction'
require 'appsignal/exception_notification'
require 'appsignal/auth_check'
require 'appsignal/version'
require 'appsignal/railtie'
