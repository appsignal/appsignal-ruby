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
    #   @note some classes may have options to set custom loggers. Their
    #     defaults are pointed to this attribute.
    #   @api private
    #   @return [Logger]
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
    #   Appsignal.config = Appsignal::Config.new(Dir.pwd, "production")
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

      @config ||= Config.new(
        Dir.pwd,
        ENV["APPSIGNAL_APP_ENV"] || ENV["RAILS_ENV"] || ENV.fetch("RACK_ENV", nil)
      )

      _start_logger

      if config.valid?
        if config.active?
          internal_logger.info "Starting AppSignal #{Appsignal::VERSION} " \
            "(#{$PROGRAM_NAME}, Ruby #{RUBY_VERSION}, #{RUBY_PLATFORM})"
          config.write_to_environment
          Appsignal::Extension.start
          Appsignal::Hooks.load_hooks

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
        internal_logger.debug("Stopping appsignal (#{called_by})")
      else
        internal_logger.debug("Stopping appsignal")
      end
      Appsignal::Extension.stop
      Appsignal::Probes.stop
    end

    def forked
      return unless active?

      Appsignal._start_logger
      internal_logger.debug("Forked process, resubscribing and restarting extension")
      Appsignal::Extension.start
    end

    def get_server_state(key)
      Appsignal::Extension.get_server_state(key)
    end

    def in_memory_logger
      @in_memory_logger ||=
        Appsignal::Utils::IntegrationMemoryLogger.new.tap do |l|
          l.formatter = log_formatter("appsignal")
        end
    end

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
        "Callng 'Appsignal.start_logger' is deprecated. " \
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
require "appsignal/rack/abstract_middleware"
require "appsignal/rack/generic_instrumentation"
require "appsignal/rack/event_handler"
require "appsignal/integrations/railtie" if defined?(::Rails)
require "appsignal/transaction"
require "appsignal/version"
require "appsignal/transmitter"
require "appsignal/heartbeat"
