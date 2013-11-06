require 'logger'
require 'rack'
require 'thread_safe'
require 'active_support/json'

module Appsignal
  class << self
    attr_accessor :config, :logger, :agent
    attr_reader :in_memory_log

    def start
      if config
        if config[:debug]
          logger.level = Logger::DEBUG
        else
          logger.level = Logger::INFO
        end
        logger.info("Starting appsignal-#{Appsignal::VERSION}")
        @agent = Appsignal::Agent.new
      else
        logger.error("Can't start, no config loaded")
      end
    end

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
      return if is_ignored_exception?(exception)
      transaction = Appsignal::Transaction.create(SecureRandom.uuid, ENV.to_hash)
      transaction.add_exception(exception)
      transaction.complete!
      Appsignal.agent.send_queue
    end

    def add_exception(exception)
      return if Appsignal::Transaction.current.nil? || exception.nil?
      unless is_ignored_exception?(exception)
        Appsignal::Transaction.current.add_exception(exception)
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

    def post_processing_middleware
      @post_processing_chain ||= Appsignal::Aggregator::PostProcessor.default_middleware
      yield @post_processing_chain if block_given?
      @post_processing_chain
    end

    def active?
      config && config[:active] == true
    end

    def is_ignored_exception?(exception)
      Appsignal.config[:ignore_exceptions].include?(exception.class.name)
    end
  end
end

require 'appsignal/agent'
require 'appsignal/aggregator'
require 'appsignal/aggregator/post_processor'
require 'appsignal/auth_check'
require 'appsignal/config'
require 'appsignal/marker'
require 'appsignal/middleware'
require 'appsignal/rack/listener'
require 'appsignal/rack/instrumentation'
require 'appsignal/transaction'
require 'appsignal/transaction/formatter'
require 'appsignal/transaction/params_sanitizer'
require 'appsignal/transmitter'
require 'appsignal/version'

require 'appsignal/integrations/passenger'
require 'appsignal/integrations/rails'
