raise 'This appsignal gem only works with rails' unless defined?(Rails)

module Appsignal
  class << self
    attr_accessor :subscriber
    attr_reader :in_memory_log

    # Convenience method for adding a transaction to the queue. This queue is
    # managed and is periodically pushed to Appsignal.
    #
    # @return [ true ] True.
    #
    # @since 0.5.0
    def enqueue(transaction)
      agent.enqueue(transaction)
    end

    def transactions
      @transactions ||= {}
    end

    def agent
      @agent ||= Appsignal::Agent.new
    end

    def logger
      @in_memory_log = StringIO.new unless @in_memory_log
      @logger ||= Logger.new(@in_memory_log).tap do |l|
        l.level = Logger::INFO
      end
    end

    def flush_in_memory_log
      Appsignal.logger << @in_memory_log.string
    end

    def logger=(l)
      @logger = l
    end

    def config
      @config ||= Appsignal::Config.new(Rails.root, Rails.env).load
    end

    def post_processing_middleware
      @post_processing_chain ||= PostProcessor.default_middleware
      yield @post_processing_chain if block_given?
      @post_processing_chain
    end

    def active?
      config && config[:active] == true
    end
  end
end

require 'appsignal/agent'
require 'appsignal/aggregator'
require 'appsignal/auth_check'
require 'appsignal/cli'
require 'appsignal/config'
require 'appsignal/exception_notification'
require 'appsignal/integrations/passenger'
require 'appsignal/listener'
require 'appsignal/marker'
require 'appsignal/middleware'
require 'appsignal/railtie'
require 'appsignal/transaction'
require 'appsignal/transmitter'
require 'appsignal/version'
