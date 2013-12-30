require 'logger'
require 'rack'
require 'thread_safe'
require 'active_support/json'

module Appsignal
  class << self
    attr_accessor :config, :logger, :agent, :in_memory_log

    def extensions
      @extensions ||= []
    end

    def initialize_extensions
      Appsignal.logger.debug('Initializing extensions')
      @extensions.each do |extension|
        Appsignal.logger.debug("Initializing #{extension}")
        extension.initializer
      end
    end

    def start
      if config
        if config[:debug]
          logger.level = Logger::DEBUG
        else
          logger.level = Logger::INFO
        end
        logger.info("Starting appsignal-#{Appsignal::VERSION}")
        initialize_extensions
        @agent = Appsignal::Agent.new
        at_exit { @agent.shutdown(true) }
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

    def start_logger(path)
      if path && File.writable?(path) && !ENV['DYNO']
        @logger = Logger.new(File.join(path, 'appsignal.log'))
        @logger.formatter = Logger::Formatter.new
      else
        @logger = Logger.new($stdout)
      end
      @logger.level = Logger::INFO
      @logger << @in_memory_log.string if @in_memory_log
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
require 'appsignal/aggregator/middleware'
require 'appsignal/auth_check'
require 'appsignal/config'
require 'appsignal/marker'
require 'appsignal/rack/listener'
require 'appsignal/rack/instrumentation'
require 'appsignal/transaction'
require 'appsignal/transaction/formatter'
require 'appsignal/transaction/params_sanitizer'
require 'appsignal/transmitter'
require 'appsignal/version'

require 'appsignal/integrations/delayed_job'
require 'appsignal/integrations/passenger'
require 'appsignal/integrations/unicorn'
require 'appsignal/integrations/rails'
require 'appsignal/integrations/sidekiq'
