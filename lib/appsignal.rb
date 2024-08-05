# frozen_string_literal: true

require "json"
require "securerandom"
require "stringio"

require "appsignal/logger"
require "appsignal/utils/stdout_and_logger_message"
require "appsignal/helpers/heartbeats"
require "appsignal/helpers/instrumentation"
require "appsignal/helpers/metrics"

# AppSignal for Ruby gem's main module.
#
# Provides method to control the AppSignal instrumentation and the system
# agent. Also provides direct access to instrumentation helpers (from
# {Appsignal::Helpers::Instrumentation}) and metrics helpers (from
# {Appsignal::Helpers::Metrics}) for ease of use.
module Appsignal
  class << self
    include Helpers::Heartbeats
    include Helpers::Instrumentation
    include Helpers::Metrics

    # The loaded AppSignal configuration.
    # Returns the current AppSignal configuration.
    #
    # Can return `nil` if no configuration has been set or automatically loaded
    # by an automatic integration or by calling {.start}.
    #
    # @example
    #   Appsignal.config
    #
    # @return [Config, nil]
    # @see configure
    # @see Config
    attr_reader :config

    # Set the AppSignal config.
    #
    # @deprecated Use {Appsignal.configure} instead.
    # @param conf [Appsignal::Config]
    # @return [void]
    # @see Config
    def config=(conf)
      Appsignal::Utils::StdoutAndLoggerMessage.warning \
        "Configuring AppSignal with `Appsignal.config=` is deprecated. " \
          "Use `Appsignal.configure { |config| ... }` to configure AppSignal. " \
          "https://docs.appsignal.com/ruby/configuration.html\n" \
          "#{caller.first}"
      @config = conf
    end

    # @api private
    def _config=(conf)
      @config = conf
    end

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
    # @!attribute [rw] internal_logger
    #   Accessor for the internal AppSignal logger.
    #
    #   Not to be confused with our logging feature.
    #   This is part of our private internal API. Do not call this method
    #   directly.
    #
    #   If no logger has been set, it will return a "in memory logger", using
    #   {Utils::IntegrationMemoryLogger}. Once AppSignal is started (using
    #   {.start}) the contents of the "in memory logger" is written to the new
    #   logger.
    #
    #   @api private
    #   @return [Utils::IntegrationLogger or Utils::IntegrationMemoryLogger]
    #   @see start
    attr_writer :internal_logger

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
    # list](https://docs.appsignal.com/ruby/integrations/) and our [Integrating
    # AppSignal](https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html)
    # guide.
    #
    # @example
    #   Appsignal.start
    #
    # @example with custom loaded configuration
    #   Appsignal.configure(:production) do |config|
    #     config.ignore_actions = ["My action"]
    #   end
    #   Appsignal.start
    #
    # @return [void]
    # @since 0.7.0
    def start
      unless extension_loaded?
        internal_logger.info("Not starting AppSignal, extension is not loaded")
        return
      end

      internal_logger.debug("Loading AppSignal gem")

      @config ||= Config.new(Config.determine_root_path, Config.determine_env)

      _start_logger

      if config.valid?
        if config.active?
          @started = true
          internal_logger.info "Starting AppSignal #{Appsignal::VERSION} " \
            "(#{$PROGRAM_NAME}, Ruby #{RUBY_VERSION}, #{RUBY_PLATFORM})"
          config.write_to_environment
          Appsignal::Extension.start
          Appsignal::Hooks.load_hooks
          Appsignal::Loaders.start

          if config[:enable_allocation_tracking] && !Appsignal::System.jruby?
            Appsignal::Extension.install_allocation_event_hook
            Appsignal::Environment.report_enabled("allocation_tracking")
          end

          Appsignal::Probes.start if config[:enable_minutely_probes]

          collect_environment_metadata
        else
          internal_logger.info("Not starting, not active for #{config.env}")
        end
      else
        internal_logger.error("Not starting, no valid config for this environment")
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
        internal_logger.debug("Stopping AppSignal (#{called_by})")
      else
        internal_logger.debug("Stopping AppSignal")
      end
      Appsignal::Extension.stop
      Appsignal::Probes.stop
    end

    # Configure the AppSignal Ruby gem using a DSL.
    #
    # Pass a block to the configure method to configure the Ruby gem.
    #
    # Each config option defined in our docs can be fetched, set and modified
    # via a helper method in the given block.
    #
    # After AppSignal has started using {start}, the configuration can not be
    # modified. Any calls to this helper will be ignored.
    #
    # This helper should not be used to configure multiple environments, like
    # done in the YAML file. Configure the environment you want active when the
    # application starts.
    #
    # @example Configure AppSignal for the application
    #   Appsignal.configure do |config|
    #     config.path = "/the/app/path"
    #     config.active = ENV["APP_ACTIVE"] == "true"
    #     config.push_api_key = File.read("appsignal_key.txt").chomp
    #     config.ignore_actions = ENDPOINTS.select { |e| e.public? }.map(&:name)
    #     config.request_headers << "MY_CUSTOM_HEADER"
    #   end
    #
    # @example Configure AppSignal for the application and select the environment
    #   Appsignal.configure(:production) do |config|
    #     config.active = true
    #   end
    #
    # @example Automatically detects the app environment
    #   # Tries to determine the app environment automatically from the
    #   # environment and the libraries it integrates with.
    #   ENV["RACK_ENV"] = "production"
    #
    #   Appsignal.configure do |config|
    #     config.env # => "production"
    #   end
    #
    # @example Calling configure multiple times for different environments resets the configuration
    #   Appsignal.configure(:development) do |config|
    #     config.ignore_actions = ["My action"]
    #   end
    #
    #   Appsignal.configure(:production) do |config|
    #     config.ignore_actions # => []
    #   end
    #
    # @example Load config without a block
    #   # This will require either ENV vars being set
    #   # or the config/appsignal.yml being present
    #   Appsignal.configure
    #   # Or for the environment given as an argument
    #   Appsignal.configure(:production)
    #
    # @param env [String, Symbol] The environment to load.
    # @param root_path [String] The path to look the `config/appsignal.yml` config file in.
    #   Defaults to the current working directory.
    # @yield [Config] Gives the {Config} instance to the block.
    # @return [void]
    # @see config
    # @see Config
    # @see https://docs.appsignal.com/ruby/configuration.html Configuration guide
    # @see https://docs.appsignal.com/ruby/configuration/options.html Configuration options
    def configure(env = nil, root_path: nil)
      if Appsignal.started?
        Appsignal.internal_logger
          .warn("AppSignal is already started. Ignoring `Appsignal.configure` call.")
        return
      end

      if config && ((env.nil? || config.env == env.to_s) &&
          (root_path.nil? || config.root_path == root_path))
        config
      else
        @config = Config.new(
          root_path || Config.determine_root_path,
          Config.determine_env(env),
          {},
          Appsignal.internal_logger,
          nil,
          false
        )
        config.load_config
      end

      config_dsl = Appsignal::Config::ConfigDSL.new(config)
      if block_given?
        yield config_dsl
        config.merge_dsl_options(config_dsl.dsl_options)
      end
      config.validate
    end

    def forked
      return unless active?

      Appsignal._start_logger
      internal_logger.debug("Forked process, resubscribing and restarting extension")
      Appsignal::Extension.start
    end

    # Load an AppSignal integration.
    #
    # Load one of the supported integrations via our loader system.
    # This will set config defaults and integratie with the library if
    # AppSignal is active upon start.
    #
    # @example Load Sinatra integrations
    #   # First load the integration
    #   Appsignal.load(:sinatra)
    #   # Start AppSignal
    #   Appsignal.start
    #
    # @example Load Sinatra integrations and define custom config
    #   # First load the integration
    #   Appsignal.load(:sinatra)
    #
    #   # Customize config
    #   Appsignal.configure do |config|
    #     config.ignore_actions = ["GET /ping"]
    #   end
    #
    #
    #   # Start AppSignal
    #   Appsignal.start
    #
    # @param integration_name [String, Symbol] Name of the integration to load.
    # @return [void]
    # @since 3.12.0
    def load(integration_name)
      Loaders.load(integration_name)
    end

    # @api private
    def get_server_state(key)
      Appsignal::Extension.get_server_state(key)
    end

    # @api private
    def in_memory_logger
      @in_memory_logger ||=
        Appsignal::Utils::IntegrationMemoryLogger.new.tap do |l|
          l.formatter = log_formatter("appsignal")
        end
    end

    # @api private
    def internal_logger
      @internal_logger ||= in_memory_logger
    end

    # @api private
    def log_formatter(prefix = nil)
      pre = "#{prefix}: " if prefix
      proc do |severity, datetime, _progname, msg|
        "[#{datetime.strftime("%Y-%m-%dT%H:%M:%S")} (process) " \
          "##{Process.pid}][#{severity}] #{pre}#{msg}\n"
      end
    end

    # @deprecated Only {.start} has to be called.
    # @return [void]
    # @since 0.7.0
    def start_logger
      callers = caller
      Appsignal::Utils::StdoutAndLoggerMessage.warning \
        "Calling 'Appsignal.start_logger' is deprecated. " \
          "The logger will be started when calling 'Appsignal.start'. " \
          "Remove the 'Appsignal.start_logger' call in the following file to " \
          "remove this message.\n#{callers.first}"
    end

    # Start the AppSignal internal logger.
    #
    # Sets the log level and sets the logger. Uses a file-based logger or the
    # STDOUT-based logger. See the `:log` configuration option.
    #
    # @api private
    # @return [void]
    def _start_logger
      if config && config[:log] == "file" && config.log_file_path
        start_internal_file_logger(config.log_file_path)
      else
        start_internal_stdout_logger
      end

      internal_logger.level =
        if config
          config.log_level
        else
          Appsignal::Config::DEFAULT_LOG_LEVEL
        end
      return unless @in_memory_logger

      messages = @in_memory_logger.messages_for_level(internal_logger.level)
      internal_logger << messages.join
      @in_memory_logger = nil
    end

    # Returns if the C-extension was loaded properly.
    #
    # @return [Boolean]
    # @see Extension
    # @since 1.0.0
    def extension_loaded?
      !!extension_loaded
    end

    # Returns if {.start} has been called before with a valid config to start
    # AppSignal.
    #
    # @return [Boolean]
    # @see Extension
    # @since 3.12.0
    def started?
      defined?(@started) ? @started : false
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
      config&.active? && extension_loaded?
    end

    private

    def start_internal_stdout_logger
      @internal_logger = Appsignal::Utils::IntegrationLogger.new($stdout)
      internal_logger.formatter = log_formatter("appsignal")
    end

    def start_internal_file_logger(path)
      @internal_logger = Appsignal::Utils::IntegrationLogger.new(path)
      internal_logger.formatter = log_formatter
    rescue SystemCallError => error
      start_internal_stdout_logger
      internal_logger.warn "Unable to start internal logger with log path '#{path}'."
      internal_logger.warn error
    end

    def collect_environment_metadata
      Appsignal::Environment.report("ruby_version") do
        "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"
      end
      Appsignal::Environment.report("ruby_engine") { RUBY_ENGINE }
      if defined?(RUBY_ENGINE_VERSION)
        Appsignal::Environment.report("ruby_engine_version") do
          RUBY_ENGINE_VERSION
        end
      end
      Appsignal::Environment.report_supported_gems
    end

    # Alias constants that have moved with a warning message that points to the
    # place to update the reference.
    def const_missing(name)
      case name
      when :Minutely
        callers = caller
        Appsignal::Utils::StdoutAndLoggerMessage.warning \
          "The constant Appsignal::Minutely has been deprecated. " \
            "Please update the constant name to Appsignal::Probes " \
            "in the following file to remove this message.\n#{callers.first}"
        Appsignal::Probes
      else
        super
      end
    end
  end
end

require "appsignal/loaders"
require "appsignal/environment"
require "appsignal/system"
require "appsignal/utils"
require "appsignal/extension"
require "appsignal/auth_check"
require "appsignal/config"
require "appsignal/event_formatter"
require "appsignal/hooks"
require "appsignal/probes"
require "appsignal/marker"
require "appsignal/garbage_collection"
require "appsignal/rack"
require "appsignal/rack/body_wrapper"
require "appsignal/rack/abstract_middleware"
require "appsignal/rack/instrumentation_middleware"
require "appsignal/rack/event_handler"
require "appsignal/integrations/railtie" if defined?(::Rails)
require "appsignal/transaction"
require "appsignal/version"
require "appsignal/transmitter"
require "appsignal/heartbeat"
