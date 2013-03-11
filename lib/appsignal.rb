raise 'This appsignal gem only works with rails' unless defined?(Rails)

module Appsignal
  class << self
    attr_accessor :subscriber, :event_payload_sanitizer

    # Convenience method for pushing an exception or transaction straight to
    # Appsignal.
    #
    # @return [ Boolean ] If successful or not
    #
    # TODO @since VERSION
    def push(exception_or_transaction)
    end

    # Convenience method for adding an exception or transaction to the queue.
    # This queue is managed and is periodically pushed to Appsignal.
    #
    # @return [ true ] True.
    #
    # TODO @since VERSION
    def queue(exception_or_transaction)
    end

    def active?
      config && config[:active] == true
    end

    def logger
      @logger ||= Logger.new("#{Rails.root}/log/appsignal.log").tap do |l|
        l.level = Logger::INFO
      end
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

    # TODO replace me with middleware stack before sending queue
    def event_payload_sanitizer
      @event_payload_sanitizer ||= proc { |event| event.payload }
    end
  end
end

require 'appsignal/cli'
require 'appsignal/config'
require 'appsignal/transmitter'
require 'appsignal/agent'
require 'appsignal/aggregator'
require 'appsignal/marker'
require 'appsignal/middleware'
require 'appsignal/transaction'
require 'appsignal/exception_notification'
require 'appsignal/auth_check'
require 'appsignal/version'
require 'appsignal/railtie'
