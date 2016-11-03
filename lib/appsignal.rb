require 'json'
require 'logger'
require 'securerandom'

module Appsignal
  class << self
    attr_accessor :config, :agent, :extension_loaded
    attr_writer :logger, :in_memory_log

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
      unless extension_loaded?
        logger.info('Not starting appsignal, extension is not loaded')
        return
      else
        logger.debug('Starting appsignal')
      end

      unless @config
        @config = Config.new(
          Dir.pwd,
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

          if config[:enable_allocation_tracking]
            Appsignal::Extension.install_allocation_event_hook
          end

          if config[:enable_gc_instrumentation]
            GC::Profiler.enable
            Appsignal::Minutely.add_gc_probe
          end

          Appsignal::Minutely.start if config[:enable_minutely_probes]
        else
          logger.info("Not starting, not active for #{config.env}")
        end
      else
        logger.error('Not starting, no valid config for this environment')
      end
    end

    def in_memory_log
      if defined?(@in_memory_log) && @in_memory_log
        @in_memory_log
      else
        @in_memory_log = StringIO.new
      end
    end

    def stop(called_by=nil)
      if called_by
        logger.debug("Stopping appsignal (#{called_by})")
      else
        logger.debug('Stopping appsignal')
      end
      Appsignal::Extension.stop
    end

    def forked
      return unless active?
      Appsignal.start_logger
      logger.debug('Forked process, resubscribing and restarting extension')
      Appsignal::Extension.start
    end

    def get_server_state(key)
      Appsignal::Extension::get_server_state(key)
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
        Appsignal.instrument(name) do
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
      stop('monitor_single_transaction')
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
      transaction = Appsignal::Transaction.new(
        SecureRandom.uuid,
        namespace,
        Appsignal::Transaction::GenericRequest.new({})
      )
      transaction.set_tags(tags) if tags
      transaction.set_error(error)
      transaction.complete
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

    def instrument(name, title=nil, body=nil, body_format=Appsignal::EventFormatter::DEFAULT)
      Appsignal::Transaction.current.start_event
      return_value = yield
      Appsignal::Transaction.current.finish_event(name, title, body, body_format)
      return_value
    end

    def instrument_sql(name, title=nil, body=nil, &block)
      instrument(name, title, body, Appsignal::EventFormatter::SQL_BODY_FORMAT, &block)
    end

    def set_gauge(key, value)
      Appsignal::Extension.set_gauge(key.to_s, value.to_f)
    rescue RangeError
      Appsignal.logger.warn("Gauge value #{value} for key '#{key}' is too big")
    end

    def set_host_gauge(key, value)
      Appsignal::Extension.set_host_gauge(key.to_s, value.to_f)
    rescue RangeError
      Appsignal.logger.warn("Host gauge value #{value} for key '#{key}' is too big")
    end

    def set_process_gauge(key, value)
      Appsignal::Extension.set_process_gauge(key.to_s, value.to_f)
    rescue RangeError
      Appsignal.logger.warn("Process gauge value #{value} for key '#{key}' is too big")
    end

    def increment_counter(key, value=1)
      Appsignal::Extension.increment_counter(key.to_s, value)
    rescue RangeError
      Appsignal.logger.warn("Counter value #{value} for key '#{key}' is too big")
    end

    def add_distribution_value(key, value)
      Appsignal::Extension.add_distribution_value(key.to_s, value.to_f)
    rescue RangeError
      Appsignal.logger.warn("Distribution value #{value} for key '#{key}' is too big")
    end

    def logger
      @logger ||= Logger.new(in_memory_log).tap do |l|
        l.level = Logger::INFO
        l.formatter = log_formatter
      end
    end

    def log_formatter(prefix = nil)
      prefix = "#{prefix}: " if prefix
      proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%dT%H:%M:%S')} (process) ##{Process.pid}][#{severity}] #{prefix}#{msg}\n"
      end
    end

    def start_logger(path_arg = nil)
      if config && config[:log] == "file" && config.log_file_path
        start_file_logger(config.log_file_path)
      else
        start_stdout_logger
      end

      logger.level =
        if config && config[:debug]
          Logger::DEBUG
        else
          Logger::INFO
        end

      if in_memory_log
        logger << in_memory_log.string
      end

      if path_arg
        logger.info('Setting the path in start_logger has no effect anymore, set it in the config instead')
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

    private

    def start_stdout_logger(prefix = "appsignal")
      @logger = Logger.new($stdout)
      logger.formatter = log_formatter(prefix)
    end

    def start_file_logger(path)
      @logger = Logger.new(path)
      logger.formatter = log_formatter
    rescue SystemCallError => error
      start_stdout_logger
      logger.warn "appsignal: Unable to start logger with log path '#{path}'."
      logger.warn "appsignal: #{error}"
    end
  end
end

require 'appsignal/utils'
require 'appsignal/extension'
require 'appsignal/auth_check'
require 'appsignal/config'
require 'appsignal/event_formatter'
require 'appsignal/hooks'
require 'appsignal/marker'
require 'appsignal/minutely'
require 'appsignal/garbage_collection_profiler'
require 'appsignal/integrations/railtie' if defined?(::Rails)
require 'appsignal/integrations/resque'
require 'appsignal/integrations/resque_active_job'
require 'appsignal/transaction'
require 'appsignal/version'
require 'appsignal/rack/generic_instrumentation'
require 'appsignal/rack/js_exception_catcher'
require 'appsignal/js_exception_transaction'
require 'appsignal/transmitter'
require 'appsignal/system'
