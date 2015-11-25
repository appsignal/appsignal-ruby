require 'logger'
require 'securerandom'

begin
  require 'active_support/notifications'
  ActiveSupport::Notifications::Fanout::Subscribers::Timed # See it it's recent enough
rescue LoadError, NameError
  require 'vendor/active_support/notifications'
end

module Appsignal
  class << self
    attr_accessor :config, :subscriber, :logger, :agent, :in_memory_log, :extension_loaded

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
      return unless extension_loaded?

      unless @config
        @config = Config.new(
          ENV['PWD'],
          ENV['APPSIGNAL_APP_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV']
        )
      end

      if config.valid?
        if config[:debug]
          logger.level = Logger::DEBUG
        else
          logger.level = Logger::INFO
        end
        if config.active?
          logger.info("Starting AppSignal #{Appsignal::VERSION} (#{$0}, Ruby #{RUBY_VERSION}, #{RUBY_PLATFORM})")
          config.write_to_environment
          Appsignal::Extension.start
          Appsignal::Hooks.load_hooks
          Appsignal::EventFormatter.initialize_formatters
          initialize_extensions
          Appsignal::Extension.install_allocation_event_hook if config[:enable_allocation_tracking]
          Appsignal::Extension.install_gc_event_hooks if config[:enable_gc_instrumentation]
          @subscriber = Appsignal::Subscriber.new
        else
          logger.info("Not starting, not active for #{config.env}")
        end
      else
        logger.error('Not starting, no valid config for this environment')
      end
    end

    def stop
      Appsignal::Extension.stop
    end

    def forked
      return unless active?
      logger.debug('Forked process, resubscribing and restarting extension')
      Appsignal::Extension.start
      @subscriber.resubscribe
    end

    # Wrap a transaction with appsignal monitoring.
    def monitor_transaction(name, env={})
      unless active?
        return yield
      end

      if name.start_with?('perform_job'.freeze)
        namespace = Appsignal::Transaction::BACKGROUND_JOB
        request   = Appsignal::Transaction::GenericRequest.new(env)
      elsif name.start_with?('process_action'.freeze)
        namespace = Appsignal::Transaction::HTTP_REQUEST
        request   = ::Rack::Request.new(env)
      else
        logger.error("Unrecognized name '#{name}'") and return
      end
      transaction = Appsignal::Transaction.create(
        SecureRandom.uuid,
        namespace,
        request
      )
      begin
        ActiveSupport::Notifications.instrument(name) do
          yield
        end
      rescue => error
        transaction.set_error(error)
        raise error
      ensure
        transaction.set_http_or_background_action(request.env)
        transaction.set_http_or_background_queue_start
        Appsignal::Transaction.complete_current!
      end
    end

    # Monitor a transaction, stop Appsignal and wait for this single transaction to be
    # flushed.
    #
    # Useful for cases such as Rake tasks and Resque-like systems where a process is
    # forked and immediately exits after the transaction finishes.
    def monitor_single_transaction(name, env={}, &block)
      monitor_transaction(name, env, &block)
    ensure
      stop
    end

    def listen_for_error(&block)
      yield
    rescue => error
      send_error(error)
      raise error
    end
    alias :listen_for_exception :listen_for_error

    def send_error(error, tags=nil, namespace=Appsignal::Transaction::HTTP_REQUEST)
      return if !active? || is_ignored_error?(error)
      unless error.is_a?(Exception)
        logger.error('Can\'t send error, given value is not an exception')
        return
      end
      transaction = Appsignal::Transaction.create(
        SecureRandom.uuid,
        namespace,
        Appsignal::Transaction::GenericRequest.new({})
      )
      transaction.set_tags(tags) if tags
      transaction.set_error(error)
      Appsignal::Transaction.complete_current!
    end
    alias :send_exception :send_error

    def set_error(exception)
      return if !active? ||
                Appsignal::Transaction.current.nil? ||
                exception.nil? ||
                is_ignored_error?(exception)
      Appsignal::Transaction.current.set_error(exception)
    end
    alias :set_exception :set_error
    alias :add_exception :set_error

    def tag_request(params={})
      return unless active?
      transaction = Appsignal::Transaction.current
      return false unless transaction
      transaction.set_tags(params)
    end
    alias :tag_job :tag_request

    def set_gauge(key, value)
      Appsignal::Extension.set_gauge(key, value.to_f)
    end

    def set_host_gauge(key, value)
      Appsignal::Extension.set_host_gauge(key, value.to_f)
    end

    def set_process_gauge(key, value)
      Appsignal::Extension.set_process_gauge(key, value.to_f)
    end

    def increment_counter(key, value)
      Appsignal::Extension.increment_counter(key, value)
    end

    def add_distribution_value(key, value)
      Appsignal::Extension.add_distribution_value(key, value.to_f)
    end

    def logger
      @in_memory_log = StringIO.new unless @in_memory_log
      @logger ||= Logger.new(@in_memory_log).tap do |l|
        l.level = Logger::INFO
        l.formatter = log_formatter
      end
    end

    def log_formatter
        proc do |severity, datetime, progname, msg|
          "[#{datetime.strftime('%Y-%m-%dT%H:%M:%S')} (process) ##{Process.pid}][#{severity}] #{msg}\n"
        end
    end

    def start_logger(path_arg=nil)
      path = Appsignal.config ? Appsignal.config.log_file_path : nil
      if path && File.writable?(File.dirname(path)) &&
         !ENV['DYNO'] &&
         !ENV['SHELLYCLOUD_DEPLOYMENT']
        @logger = Logger.new(path)
        @logger.formatter = log_formatter
      else
        @logger = Logger.new($stdout)
        @logger.formatter = lambda do |severity, datetime, progname, msg|
          "appsignal: #{msg}\n"
        end
      end
      @logger.level = Logger::INFO
      @logger << @in_memory_log.string if @in_memory_log

      if path_arg
        @logger.info('Setting the path in start_logger has no effect anymore, set it in the config instead')
      end
    end

    def extension_loaded?
      !!@extension_loaded
    end

    def active?
      config && config.active? && extension_loaded?
    end

    def is_ignored_error?(error)
      Appsignal.config[:ignore_errors].include?(error.class.name)
    end
    alias :is_ignored_exception? :is_ignored_error?

    def is_ignored_action?(action)
      Appsignal.config[:ignore_actions].include?(action)
    end

    # Convenience method for skipping instrumentations around a block of code.
    #
    # @since 0.8.7
    def without_instrumentation
      Appsignal::Transaction.current.pause! if Appsignal::Transaction.current
      yield
    ensure
      Appsignal::Transaction.current.resume! if Appsignal::Transaction.current
    end
  end
end

require 'appsignal/extension'
require 'appsignal/auth_check'
require 'appsignal/config'
require 'appsignal/event_formatter'
require 'appsignal/hooks'
require 'appsignal/marker'
require 'appsignal/params_sanitizer'
require 'appsignal/integrations/railtie' if defined?(::Rails)
require 'appsignal/subscriber'
require 'appsignal/transaction'
require 'appsignal/version'
require 'appsignal/rack/js_exception_catcher'
require 'appsignal/js_exception_transaction'
require 'appsignal/transmitter'
