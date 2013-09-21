begin
  require "rails" unless defined?(Rails)
rescue
  raise 'This appsignal gem only works with rails'
end

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

    def listen_for_exception(&block)
      yield
    rescue Exception => exception
      send_exception(exception)
      raise exception
    end

    def send_exception(exception)
      unless is_ignored_exception?(exception)
        Appsignal.agent
        env = ENV.to_hash

        transaction = Appsignal::Transaction.create(SecureRandom.uuid, env)
        transaction.add_exception(
          Appsignal::ExceptionNotification.new(env, exception, false)
        )
        transaction.complete!
        Appsignal.agent.send_queue
      end
    end

    def tag_request(params={})
      transaction = Appsignal::Transaction.current
      return false unless transaction
      transaction.set_tags(params)
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
        l.formatter = Logger::Formatter.new
      end
    end

    def flush_in_memory_log
      Appsignal.logger << @in_memory_log.string
    end

    def json
      ActiveSupport::JSON
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

    def is_ignored_exception?(exception)
      Array.wrap(Appsignal.config[:ignore_exceptions]).
        include?(exception.class.name)
    end
  end
end

require 'appsignal/agent'
require 'appsignal/aggregator'
require 'appsignal/auth_check'
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
