require "json"
require "logger"
require "securerandom"

# AppSignal for Ruby gem's main module.
#
# Provides method to control the AppSignal instrumentation and the system agent.
# Also provides instrumentation helpers for ease of use.
module Appsignal
  class << self
    extend Gem::Deprecate

    # Accessor for the AppSignal configuration.
    # Return the current AppSignal configuration.
    #
    # Can return `nil` if no configuration has been set or automatically loaded
    # by an automatic integration or by calling {.start}.
    #
    # @example
    #   Appsignal.config
    #
    # @example Setting the configuration
    #   Appsignal.config = Appsignal::Config.new(Dir.pwd, "production")
    #
    # @return [Config, nil]
    # @see Config
    attr_accessor :config
    # Accessor for toggle if the AppSignal C-extension is loaded.
    #
    # Can be `nil` if extension has not been loaded yet. See
    # {.extension_loaded?} for a boolean return value.
    #
    # @api private
    # @return [Boolean, nil]
    # @see Extension
    # @see extension_loaded?
    attr_accessor :extension_loaded
    # @!attribute [rw] logger
    #   Accessor for the AppSignal logger.
    #
    #   If no logger has been set, it will return a "in memory logger", using
    #   `in_memory_log`. Once AppSignal is started (using {.start}) the
    #   contents of the "in memory logger" is written to the new logger.
    #
    #   @note some classes may have options to set custom loggers. Their
    #     defaults are pointed to this attribute.
    #   @api private
    #   @return [Logger]
    #   @see start_logger
    attr_writer :logger

    # @api private
    def extensions
      @extensions ||= []
    end

    # @api private
    def initialize_extensions
      Appsignal.logger.debug("Initializing extensions")
      extensions.each do |extension|
        Appsignal.logger.debug("Initializing #{extension}")
        extension.initializer
      end
    end

    # @api private
    def testing?
      false
    end

    # Start the AppSignal integration.
    #
    # Starts AppSignal with the given configuration. If no configuration is set
    # yet it will try to automatically load the configuration using the
    # environment loaded from environment variables and the currently working
    # directory.
    #
    # This is not required for the automatic integrations AppSignal offers, but
    # this is required for all non-automatic integrations and pure Ruby
    # applications. For more information, see our [integrations
    # list](http://docs.appsignal.com/ruby/integrations/) and our [Integrating
    # AppSignal](http://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html)
    # guide.
    #
    # To start the logger see {.start_logger}.
    #
    # @example
    #   Appsignal.start
    #
    # @example with custom loaded configuration
    #   Appsignal.config = Appsignal::Config.new(Dir.pwd, "production")
    #   Appsignal.start
    #
    # @return [void]
    # @since 0.7.0
    def start # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      unless extension_loaded?
        logger.info("Not starting appsignal, extension is not loaded")
        return
      end

      logger.debug("Starting appsignal")

      unless @config
        @config = Config.new(
          Dir.pwd,
          ENV["APPSIGNAL_APP_ENV"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"]
        )
      end

      if config.valid?
        logger.level =
          if config[:debug]
            Logger::DEBUG
          else
            Logger::INFO
          end
        if config.active?
          logger.info "Starting AppSignal #{Appsignal::VERSION} "\
            "(#{$PROGRAM_NAME}, Ruby #{RUBY_VERSION}, #{RUBY_PLATFORM})"
          config.write_to_environment
          Appsignal::Extension.start
          Appsignal::Hooks.load_hooks
          initialize_extensions

          if config[:enable_allocation_tracking] && !Appsignal::System.jruby?
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
        logger.error("Not starting, no valid config for this environment")
      end
    end

    # Stop AppSignal's agent.
    #
    # Stops the AppSignal agent. Call this before the end of your program to
    # make sure the agent is stopped as well.
    #
    # @example
    #   Appsignal.start
    #   # Run your application
    #   Appsignal.stop
    #
    # @param called_by [String] Name of the thing that requested the agent to
    #   be stopped. Will be used in the AppSignal log file.
    # @return [void]
    # @since 1.0.0
    def stop(called_by = nil)
      if called_by
        logger.debug("Stopping appsignal (#{called_by})")
      else
        logger.debug("Stopping appsignal")
      end
      Appsignal::Extension.stop
    end

    def forked
      return unless active?
      Appsignal.start_logger
      logger.debug("Forked process, resubscribing and restarting extension")
      Appsignal::Extension.start
    end

    def get_server_state(key)
      Appsignal::Extension.get_server_state(key)
    end

    # Creates an AppSignal transaction for the given block.
    #
    # If AppSignal is not {.active?} it will still execute the block, but not
    # create a transaction for it.
    #
    # A event is created for this transaction with the name given in the `name`
    # argument. The event name must start with either `perform_job` or
    # `process_action` to differentiate between the "web" and "background"
    # namespace. Custom namespaces are not supported by this helper method.
    #
    # This helper method also captures any exception that occurs in the given
    # block.
    #
    # The other (request) `env` argument hash keys, not listed here, can be
    # found on the {Appsignal::Transaction::ENV_METHODS} array.
    # Each of these keys are available as keys in the `env` hash argument.
    #
    # @example
    #   Appsignal.monitor_transaction("perform_job.nightly_update") do
    #     # your code
    #   end
    #
    # @example with an environment
    #   Appsignal.monitor_transaction(
    #     "perform_job.nightly_update",
    #     :metadata => { "user_id" => 1 }
    #   ) do
    #     # your code
    #   end
    #
    # @param name [String] main event name.
    # @param env [Hash<Symbol, Object>]
    # @option env [Hash<Symbol/String, Object>] :params Params for the
    #   monitored request/job, see {Appsignal::Transaction#params=} for more
    #   information.
    # @option env [String] :controller name of the controller in which the
    #   transaction was recorded.
    # @option env [String] :class name of the Ruby class in which the
    #   transaction was recorded. If `:controller` is also given, `:controller`
    #   is used instead.
    # @option env [String] :action name of the controller action in which the
    #   transaction was recorded.
    # @option env [String] :method name of the Ruby method in which the
    #   transaction was recorded. If `:action` is also given, `:action`
    #   is used instead.
    # @option env [Integer] :queue_start the moment the request/job was queued.
    #   Used to track how long requests/jobs were queued before being executed.
    # @option env [Hash<Symbol/String, String/Fixnum>] :metadata Additional
    #   metadata for the transaction, see {Appsignal::Transaction#set_metadata}
    #   for more information.
    # @yield the block to monitor.
    # @raise [Exception] any exception that occurs within the given block is re-raised by
    #   this method.
    # @return [Object] the value of the given block is returned.
    # @since 0.10.0
    def monitor_transaction(name, env = {})
      unless active?
        return yield
      end

      if name.start_with?("perform_job".freeze)
        namespace = Appsignal::Transaction::BACKGROUND_JOB
        request   = Appsignal::Transaction::GenericRequest.new(env)
      elsif name.start_with?("process_action".freeze)
        namespace = Appsignal::Transaction::HTTP_REQUEST
        request   = ::Rack::Request.new(env)
      else
        logger.error("Unrecognized name '#{name}'")
        return
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
      rescue Exception => error # rubocop:disable Lint/RescueException
        transaction.set_error(error)
        raise error
      ensure
        transaction.set_http_or_background_action(request.env)
        transaction.set_http_or_background_queue_start
        Appsignal::Transaction.complete_current!
      end
    end

    # Monitor a transaction, stop AppSignal and wait for this single
    # transaction to be flushed.
    #
    # Useful for cases such as Rake tasks and Resque-like systems where a
    # process is forked and immediately exits after the transaction finishes.
    #
    # @see monitor_transaction
    def monitor_single_transaction(name, env = {}, &block)
      monitor_transaction(name, env, &block)
    ensure
      stop("monitor_single_transaction")
    end

    # Listen for an error to occur and send it to AppSignal.
    #
    # Uses {.send_error} to directly send the error in a separate transaction.
    # Does not add the error to the current transaction.
    #
    # Make sure that AppSignal is integrated in your application beforehand.
    # AppSignal won't record errors unless {Config#active?} is `true`.
    #
    # @example
    #   # my_app.rb
    #   # setup AppSignal beforehand
    #
    #   Appsignal.listen_for_error do
    #     # my code
    #     raise "foo"
    #   end
    #
    # @see Transaction.set_tags
    # @see Transaction.set_namespace
    # @see .send_error
    # @see https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html
    #   AppSignal integration guide
    #
    # @param tags [Hash, nil]
    # @param namespace [String] the namespace for this error.
    # @yield yields the given block.
    # @return [Object] returns the return value of the given block.
    def listen_for_error(tags = nil, namespace = Appsignal::Transaction::HTTP_REQUEST)
      yield
    rescue Exception => error # rubocop:disable Lint/RescueException
      send_error(error, tags, namespace)
      raise error
    end
    alias :listen_for_exception :listen_for_error

    # Send an error to AppSignal regardless of the context.
    #
    # Records and send the exception to AppSignal.
    #
    # This instrumentation helper does not require a transaction to be active,
    # it starts a new transaction by itself.
    #
    # Use {.set_error} if your want to add an exception to the current
    # transaction.
    #
    # **Note**: Does not do anything if AppSignal is not active or when the
    # "error" is not a class extended from Ruby's Exception class.
    #
    # @example Send an exception
    #   begin
    #     raise "oh no!"
    #   rescue => e
    #     Appsignal.send_error(e)
    #   end
    #
    # @example Send an exception with tags
    #   begin
    #     raise "oh no!"
    #   rescue => e
    #     Appsignal.send_error(e, :key => "value")
    #   end
    #
    # @param error [Exception] The error to send to AppSignal.
    # @param tags [Hash{String, Symbol => String, Symbol, Integer}] Additional
    #   tags to add to the error. See also {.tag_request}.
    # @param namespace [String] The namespace in which the error occurred.
    #   See also {.set_namespace}.
    # @return [void]
    #
    # @see http://docs.appsignal.com/ruby/instrumentation/exception-handling.html
    #   Exception handling guide
    # @see http://docs.appsignal.com/ruby/instrumentation/tagging.html
    #   Tagging guide
    # @since 0.6.0
    def send_error(error, tags = nil, namespace = Appsignal::Transaction::HTTP_REQUEST)
      return unless active?
      unless error.is_a?(Exception)
        logger.error("Can't send error, given value is not an exception")
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

    # Set an error on the current transaction.
    #
    # **Note**: Does not do anything if AppSignal is not active, no transaction
    # is currently active or when the "error" is not a class extended from
    # Ruby's Exception class.
    #
    # @example Manual instrumentation of set_error.
    #   # Manually starting AppSignal here
    #   # Manually starting a transaction here.
    #   begin
    #     raise "oh no!"
    #   rescue => e
    #     Appsignal.set_error(error)
    #   end
    #   # Manually completing the transaction here.
    #   # Manually stopping AppSignal here
    #
    # @example In a Rails application
    #   class SomeController < ApplicationController
    #     # The AppSignal transaction is created by our integration for you.
    #     def create
    #       # Do something that breaks
    #     rescue => e
    #       Appsignal.set_error(e)
    #     end
    #   end
    #
    # @param exception [Exception] The error to add to the current transaction.
    # @param tags [Hash{String, Symbol => String, Symbol, Integer}] Additional
    #   tags to add to the error. See also {.tag_request}.
    # @param namespace [String] The namespace in which the error occurred.
    #   See also {.set_namespace}.
    # @return [void]
    #
    # @see Transaction#set_error
    # @see http://docs.appsignal.com/ruby/instrumentation/exception-handling.html
    #   Exception handling guide
    # @since 0.6.6
    def set_error(exception, tags = nil, namespace = nil)
      return if !active? ||
          Appsignal::Transaction.current.nil? ||
          exception.nil?
      transaction = Appsignal::Transaction.current
      transaction.set_error(exception)
      transaction.set_tags(tags) if tags
      transaction.set_namespace(namespace) if namespace
    end
    alias :set_exception :set_error
    alias :add_exception :set_error

    # Set a custom action name for the current transaction.
    #
    # When using an integration such as the Rails or Sinatra AppSignal will try
    # to find the action name from the controller or endpoint for you.
    #
    # If you want to customize the action name as it appears on AppSignal.com
    # you can use this method. This overrides the action name AppSignal
    # generates in an integration.
    #
    # @example in a Rails controller
    #   class SomeController < ApplicationController
    #     before_action :set_appsignal_action
    #
    #     def set_appsignal_action
    #       Appsignal.set_action("DynamicController#dynamic_method")
    #     end
    #   end
    #
    # @param action [String]
    # @return [void]
    # @see Transaction#set_action
    # @since 2.2.0
    def set_action(action)
      return if !active? ||
          Appsignal::Transaction.current.nil? ||
          action.nil?
      Appsignal::Transaction.current.set_action(action)
    end

    # Set a custom namespace for the current transaction.
    #
    # When using an integration such as Rails or Sidekiq AppSignal will try to
    # find a appropriate namespace for the transaction.
    #
    # A Rails controller will be automatically put in the "http_request"
    # namespace, while a Sidekiq background job is put in the "background_job"
    # namespace.
    #
    # Note: The "http_request" namespace gets transformed on AppSignal.com to
    # "Web" and "background_job" gets transformed to "Background".
    #
    # If you want to customize the namespace in which transactions appear you
    # can use this method. This overrides the namespace AppSignal uses by
    # default.
    #
    # A common request we've seen is to split the administration panel from the
    # main application.
    #
    # @example create a custom admin namespace
    #   class AdminController < ApplicationController
    #     before_action :set_appsignal_namespace
    #
    #     def set_appsignal_namespace
    #       Appsignal.set_namespace("admin")
    #     end
    #   end
    #
    # @param namespace [String]
    # @return [void]
    # @see Transaction#set_namespace
    # @since 2.2.0
    def set_namespace(namespace)
      return if !active? ||
          Appsignal::Transaction.current.nil? ||
          namespace.nil?
      Appsignal::Transaction.current.set_namespace(namespace)
    end

    # Set tags on the current transaction.
    #
    # Tags are extra bits of information that are added to transaction and
    # appear on sample details pages on AppSignal.com.
    #
    # @example
    #   Appsignal.tag_request(:locale => "en")
    #   Appsignal.tag_request("locale" => "en")
    #   Appsignal.tag_request("user_id" => 1)
    #
    # @example Nested hashes are not supported
    #   # Bad
    #   Appsignal.tag_request(:user => { :locale => "en" })
    #
    # @example in a Rails controller
    #   class SomeController < ApplicationController
    #     before_action :set_appsignal_tags
    #
    #     def set_appsignal_tags
    #       Appsignal.tag_request(:locale => I18n.locale)
    #     end
    #   end
    #
    # @param tags [Hash] Collection of tags.
    # @option tags [String, Symbol, Integer] :any
    #   The name of the tag as a Symbol.
    # @option tags [String, Symbol, Integer] "any"
    #   The name of the tag as a String.
    # @return [void]
    #
    # @see Transaction.set_tags
    # @see http://docs.appsignal.com/ruby/instrumentation/tagging.html
    #   Tagging guide
    def tag_request(tags = {})
      return unless active?
      transaction = Appsignal::Transaction.current
      return false unless transaction
      transaction.set_tags(tags)
    end
    alias :tag_job :tag_request

    # Instrument helper for AppSignal.
    #
    # For more help, read our custom instrumentation guide, listed under "See
    # also".
    #
    # @example Simple instrumentation
    #   Appsignal.instrument("fetch.issue_fetcher") do
    #     # To be instrumented code
    #   end
    #
    # @example Instrumentation with title and body
    #   Appsignal.instrument(
    #     "fetch.issue_fetcher",
    #     "Fetching issue",
    #     "GitHub API"
    #   ) do
    #     # To be instrumented code
    #   end
    #
    # @param name [String] Name of the instrumented event. Read our event
    #   naming guide listed under "See also".
    # @param title [String, nil] Human readable name of the event.
    # @param body [String, nil] Value of importance for the event, such as the
    #   server against an API call is made.
    # @param body_format [Integer] Enum for the type of event that is
    #   instrumented. Accepted values are {EventFormatter::DEFAULT} and
    #   {EventFormatter::SQL_BODY_FORMAT}, but we recommend you use
    #   {.instrument_sql} instead of {EventFormatter::SQL_BODY_FORMAT}.
    # @yield yields the given block of code instrumented in an AppSignal
    #   event.
    # @return [Object] Returns the block's return value.
    #
    # @see Appsignal::Transaction#instrument
    # @see .instrument_sql
    # @see http://docs.appsignal.com/ruby/instrumentation/instrumentation.html
    #   AppSignal custom instrumentation guide
    # @see http://docs.appsignal.com/api/event-names.html
    #   AppSignal event naming guide
    # @since 1.3.0
    def instrument(name, title = nil, body = nil, body_format = Appsignal::EventFormatter::DEFAULT)
      Appsignal::Transaction.current.start_event
      yield if block_given?
    ensure
      Appsignal::Transaction.current.finish_event(name, title, body, body_format)
    end

    # Instrumentation helper for SQL queries.
    #
    # This helper filters out values from SQL queries so you don't have to.
    #
    # @example SQL query instrumentation
    #   Appsignal.instrument_sql("perform.query", nil, "SELECT * FROM ...") do
    #     # To be instrumented code
    #   end
    #
    # @example SQL query instrumentation
    #   Appsignal.instrument_sql("perform.query", nil, "WHERE email = 'foo@..'") do
    #     # query value will replace 'foo..' with a question mark `?`.
    #   end
    #
    # @param name [String] Name of the instrumented event. Read our event
    #   naming guide listed under "See also".
    # @param title [String, nil] Human readable name of the event.
    # @param body [String, nil] SQL query that's being executed.
    # @yield yields the given block of code instrumented in an AppSignal event.
    # @return [Object] Returns the block's return value.
    #
    # @see .instrument
    # @see http://docs.appsignal.com/ruby/instrumentation/instrumentation.html
    #   AppSignal custom instrumentation guide
    # @see http://docs.appsignal.com/api/event-names.html
    #   AppSignal event naming guide
    # @since 2.0.0
    def instrument_sql(name, title = nil, body = nil, &block)
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

    def increment_counter(key, value = 1)
      Appsignal::Extension.increment_counter(key.to_s, value)
    rescue RangeError
      Appsignal.logger.warn("Counter value #{value} for key '#{key}' is too big")
    end

    def add_distribution_value(key, value)
      Appsignal::Extension.add_distribution_value(key.to_s, value.to_f)
    rescue RangeError
      Appsignal.logger.warn("Distribution value #{value} for key '#{key}' is too big")
    end

    # In memory logger used before any logger is started with {.start_logger}.
    #
    # The contents of this logger are flushed to the logger in {.start_logger}.
    #
    # @api private
    # @return [StringIO]
    def in_memory_log
      if defined?(@in_memory_log) && @in_memory_log
        @in_memory_log
      else
        @in_memory_log = StringIO.new
      end
    end

    def logger
      @logger ||= Logger.new(in_memory_log).tap do |l|
        l.level = Logger::INFO
        l.formatter = log_formatter("appsignal")
      end
    end

    # @api private
    def log_formatter(prefix = nil)
      pre = "#{prefix}: " if prefix
      proc do |severity, datetime, _progname, msg|
        "[#{datetime.strftime("%Y-%m-%dT%H:%M:%S")} (process) "\
          "##{Process.pid}][#{severity}] #{pre}#{msg}\n"
      end
    end

    # Start the AppSignal logger.
    #
    # Sets the log level and sets the logger. Uses a file-based logger or the
    # STDOUT-based logger. See the `:log` configuration option.
    #
    # @param path_arg [nil] Deprecated param. Use the `:log_path`
    #   configuration option instead.
    # @return [void]
    # @since 0.7.0
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
        logger.info("Setting the path in start_logger has no effect anymore, set it in the config instead")
      end
    end

    # Returns if the C-extension was loaded properly.
    #
    # @return [Boolean]
    # @see Extension
    # @since 1.0.0
    def extension_loaded?
      !!extension_loaded
    end

    # Returns the active state of the AppSignal integration.
    #
    # Conditions apply for AppSignal to be marked as active:
    #
    # - There is a config set on the {.config} attribute.
    # - The set config is active {Config.active?}.
    # - The AppSignal Extension is loaded {.extension_loaded?}.
    #
    # This logic is used within instrument helper such as {.instrument} so it's
    # not necessary to wrap {.instrument} calls with this method.
    #
    # @example Do this
    #   Appsignal.instrument(..) do
    #     # Do this
    #   end
    #
    # @example Don't do this
    #   if Appsignal.active?
    #     Appsignal.instrument(..) do
    #       # Don't do this
    #     end
    #   end
    #
    # @return [Boolean]
    # @since 0.2.7
    def active?
      config && config.active? && extension_loaded?
    end

    # @deprecated No replacement
    def is_ignored_error?(error) # rubocop:disable Style/PredicateName
      Appsignal.config[:ignore_errors].include?(error.class.name)
    end
    alias :is_ignored_exception? :is_ignored_error?
    deprecate :is_ignored_error?, :none, 2017, 3

    # @deprecated No replacement
    def is_ignored_action?(action) # rubocop:disable Style/PredicateName
      Appsignal.config[:ignore_actions].include?(action)
    end
    deprecate :is_ignored_action?, :none, 2017, 3

    # Convenience method for skipping instrumentations around a block of code.
    #
    # @example
    #   Appsignal.without_instrumentation do
    #     # Complex code here
    #   end
    #
    # @yield block of code that shouldn't be instrumented.
    # @return [Object] Returns the return value of the block.
    # @since 0.8.7
    def without_instrumentation
      Appsignal::Transaction.current.pause! if Appsignal::Transaction.current
      yield
    ensure
      Appsignal::Transaction.current.resume! if Appsignal::Transaction.current
    end

    private

    def start_stdout_logger
      @logger = Logger.new($stdout)
      logger.formatter = log_formatter("appsignal")
    end

    def start_file_logger(path)
      @logger = Logger.new(path)
      logger.formatter = log_formatter
    rescue SystemCallError => error
      start_stdout_logger
      logger.warn "Unable to start logger with log path '#{path}'."
      logger.warn error
    end
  end
end

require "appsignal/system"
require "appsignal/utils"
require "appsignal/extension"
require "appsignal/auth_check"
require "appsignal/config"
require "appsignal/event_formatter"
require "appsignal/hooks"
require "appsignal/marker"
require "appsignal/minutely"
require "appsignal/garbage_collection_profiler"
require "appsignal/integrations/railtie" if defined?(::Rails)
require "appsignal/integrations/resque"
require "appsignal/integrations/resque_active_job"
require "appsignal/transaction"
require "appsignal/version"
require "appsignal/rack/generic_instrumentation"
require "appsignal/rack/js_exception_catcher"
require "appsignal/js_exception_transaction"
require "appsignal/transmitter"
