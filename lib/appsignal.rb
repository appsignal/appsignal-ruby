require 'logger'
require 'rack'
require 'thread_safe'
require 'securerandom'
require 'json'

begin
  require 'active_support/notifications'
  ActiveSupport::Notifications::Fanout::Subscribers::Timed # See it it's recent enough
rescue LoadError, NameError
  require 'vendor/active_support/notifications'
end

module Appsignal
  class << self
    attr_accessor :config, :subscriber, :logger, :agent, :in_memory_log

    def load_integrations
      require 'appsignal/integrations/delayed_job'
      require 'appsignal/integrations/sidekiq'
      require 'appsignal/integrations/resque'
    end

    def load_instrumentations
      require 'appsignal/instrumentations/net_http' if config[:instrument_net_http]
    end

    def extensions
      @extensions ||= []
    end

    def initialize_extensions
      Appsignal.logger.debug('Initializing extensions')
      extensions.each do |extension|
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
        if config.active?
          logger.info("Starting AppSignal #{Appsignal::VERSION} on #{RUBY_VERSION}/#{RUBY_PLATFORM}")
          config.write_to_environment
          Appsignal::Extension.start
          load_integrations
          load_instrumentations
          Appsignal::EventFormatter.initialize_formatters
          initialize_extensions
          @subscriber = Appsignal::Subscriber.new
        else
          logger.info("Not starting, not active for #{config.env}")
        end
      else
        logger.error('Can\'t start, no config loaded')
      end
    end

    def monitor_transaction(name, payload={})
      unless active?
        yield
        return
      end

      begin
        Appsignal::Transaction.create(SecureRandom.uuid, ENV.to_hash)
        ActiveSupport::Notifications.instrument(name, payload) do
          yield
        end
      rescue Exception => exception
        Appsignal.set_exception(exception)
        raise exception
      ensure
        Appsignal::Transaction.complete_current!
      end
    end

    def listen_for_exception(&block)
      yield
    rescue Exception => exception
      send_exception(exception)
      raise exception
    end

    def send_exception(exception, tags=nil)
      return if !active? || is_ignored_exception?(exception)
      transaction = Appsignal::Transaction.create(SecureRandom.uuid, ENV.to_hash)
      transaction.set_tags(tags) if tags
      transaction.set_error(exception)
      Appsignal::Transaction.complete_current!
    end

    def set_exception(exception)
      return if !active? ||
                Appsignal::Transaction.current.nil? ||
                exception.nil? ||
                is_ignored_exception?(exception)
      Appsignal::Transaction.current.set_error(exception)
    end

    def tag_request(params={})
      return unless active?
      transaction = Appsignal::Transaction.current
      return false unless transaction
      transaction.set_tags(params)
    end
    alias :tag_job :tag_request

    def logger
      @in_memory_log = StringIO.new unless @in_memory_log
      @logger ||= Logger.new(@in_memory_log).tap do |l|
        l.level = Logger::INFO
        l.formatter = Logger::Formatter.new
      end
    end

    def start_logger(path)
      if path && File.writable?(path) &&
         !ENV['DYNO'] &&
         !ENV['SHELLYCLOUD_DEPLOYMENT']
        @logger = Logger.new(File.join(path, 'appsignal.log'))
        @logger.formatter = Logger::Formatter.new
      else
        @logger = Logger.new($stdout)
        @logger.formatter = lambda do |severity, datetime, progname, msg|
          "appsignal: #{msg}\n"
        end
      end
      @logger.level = Logger::INFO
      @logger << @in_memory_log.string if @in_memory_log
    end

    def active?
      config && config.active?
    end

    def is_ignored_exception?(exception)
      Appsignal.config[:ignore_exceptions].include?(exception.class.name)
    end

    def is_ignored_action?(action)
      Appsignal.config[:ignore_actions].include?(action)
    end

    # Convenience method for skipping instrumentations around a block of code.
    #
    # @since 0.8.7
    def without_instrumentation
      agent.paused = true if agent
      yield
    ensure
      agent.paused = false if agent
    end
  end
end

require 'appsignal_extension'
require 'appsignal/auth_check'
require 'appsignal/config'
require 'appsignal/event_formatter'
require 'appsignal/marker'
require 'appsignal/params_sanitizer'
require 'appsignal/subscriber'
require 'appsignal/transaction'
require 'appsignal/version'
require 'appsignal/rack/listener'
require 'appsignal/rack/instrumentation'
require 'appsignal/integrations/rails'
