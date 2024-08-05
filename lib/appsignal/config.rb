# frozen_string_literal: true

require "erb"
require "yaml"
require "uri"
require "socket"
require "tmpdir"

module Appsignal
  class Config
    include Appsignal::Utils::StdoutAndLoggerMessage

    # @api private
    def self.loader_defaults
      @loader_defaults ||= []
    end

    # @api private
    def self.add_loader_defaults(name, options)
      loader_defaults << [name, options]
    end

    # Determine which env AppSignal should initialize with.
    # @api private
    def self.determine_env(initial_env = nil)
      [
        initial_env,
        ENV.fetch("APPSIGNAL_APP_ENV", nil),
        ENV.fetch("RAILS_ENV", nil),
        ENV.fetch("RACK_ENV", nil)
      ].compact.each do |env|
        return env if env
      end

      loader_defaults.reverse.each do |(_loader_name, loader_defaults)|
        env = loader_defaults[:env]
        return env if env
      end

      nil
    end

    # Determine which root path AppSignal should initialize with.
    # @api private
    def self.determine_root_path
      loader_defaults.reverse.each do |(_loader_name, loader_defaults)|
        root_path = loader_defaults[:root_path]
        return root_path if root_path
      end

      Dir.pwd
    end

    # @api private
    DEFAULT_CONFIG = {
      :activejob_report_errors => "all",
      :ca_file_path => File.expand_path(File.join("../../../resources/cacert.pem"), __FILE__),
      :debug => false,
      :dns_servers => [],
      :enable_allocation_tracking => true,
      :enable_host_metrics => true,
      :enable_minutely_probes => true,
      :enable_statsd => true,
      :enable_nginx_metrics => false,
      :enable_gvl_global_timer => true,
      :enable_gvl_waiting_threads => true,
      :enable_rails_error_reporter => true,
      :enable_rake_performance_instrumentation => false,
      :endpoint => "https://push.appsignal.com",
      :files_world_accessible => true,
      :filter_metadata => [],
      :filter_parameters => [],
      :filter_session_data => [],
      :ignore_actions => [],
      :ignore_errors => [],
      :ignore_logs => [],
      :ignore_namespaces => [],
      :instrument_http_rb => true,
      :instrument_net_http => true,
      :instrument_redis => true,
      :instrument_sequel => true,
      :log => "file",
      :logging_endpoint => "https://appsignal-endpoint.net",
      :request_headers => %w[
        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_CONNECTION
        CONTENT_LENGTH PATH_INFO HTTP_RANGE
        REQUEST_METHOD REQUEST_PATH SERVER_NAME SERVER_PORT
        SERVER_PROTOCOL
      ],
      :send_environment_metadata => true,
      :send_params => true,
      :sidekiq_report_errors => "all",
      :transaction_debug_mode => false
    }.freeze

    # @api private
    DEFAULT_LOG_LEVEL = ::Logger::INFO
    # Map from the `log_level` config option to Ruby's Logger level value.
    #
    # The trace level doesn't exist in the Ruby logger so it's mapped to debug.
    # @api private
    LOG_LEVEL_MAP = {
      "error" => ::Logger::ERROR,
      "warn" => ::Logger::WARN,
      "warning" => ::Logger::WARN,
      "info" => ::Logger::INFO,
      "debug" => ::Logger::DEBUG,
      "trace" => ::Logger::DEBUG
    }.freeze

    # @api private
    ENV_STRING_KEYS = {
      "APPSIGNAL_ACTIVEJOB_REPORT_ERRORS" => :activejob_report_errors,
      "APPSIGNAL_APP_NAME" => :name,
      "APPSIGNAL_BIND_ADDRESS" => :bind_address,
      "APPSIGNAL_CA_FILE_PATH" => :ca_file_path,
      "APPSIGNAL_HOSTNAME" => :hostname,
      "APPSIGNAL_HOST_ROLE" => :host_role,
      "APPSIGNAL_HTTP_PROXY" => :http_proxy,
      "APPSIGNAL_LOG" => :log,
      "APPSIGNAL_LOG_LEVEL" => :log_level,
      "APPSIGNAL_LOG_PATH" => :log_path,
      "APPSIGNAL_LOGGING_ENDPOINT" => :logging_endpoint,
      "APPSIGNAL_PUSH_API_ENDPOINT" => :endpoint,
      "APPSIGNAL_PUSH_API_KEY" => :push_api_key,
      "APPSIGNAL_SIDEKIQ_REPORT_ERRORS" => :sidekiq_report_errors,
      "APPSIGNAL_STATSD_PORT" => :statsd_port,
      "APPSIGNAL_WORKING_DIRECTORY_PATH" => :working_directory_path,
      "APPSIGNAL_WORKING_DIR_PATH" => :working_dir_path,
      "APP_REVISION" => :revision
    }.freeze
    # @api private
    ENV_BOOLEAN_KEYS = {
      "APPSIGNAL_ACTIVE" => :active,
      "APPSIGNAL_DEBUG" => :debug,
      "APPSIGNAL_ENABLE_ALLOCATION_TRACKING" => :enable_allocation_tracking,
      "APPSIGNAL_ENABLE_HOST_METRICS" => :enable_host_metrics,
      "APPSIGNAL_ENABLE_MINUTELY_PROBES" => :enable_minutely_probes,
      "APPSIGNAL_ENABLE_STATSD" => :enable_statsd,
      "APPSIGNAL_ENABLE_NGINX_METRICS" => :enable_nginx_metrics,
      "APPSIGNAL_ENABLE_GVL_GLOBAL_TIMER" => :enable_gvl_global_timer,
      "APPSIGNAL_ENABLE_GVL_WAITING_THREADS" => :enable_gvl_waiting_threads,
      "APPSIGNAL_ENABLE_RAILS_ERROR_REPORTER" => :enable_rails_error_reporter,
      "APPSIGNAL_ENABLE_RAKE_PERFORMANCE_INSTRUMENTATION" =>
        :enable_rake_performance_instrumentation,
      "APPSIGNAL_FILES_WORLD_ACCESSIBLE" => :files_world_accessible,
      "APPSIGNAL_INSTRUMENT_HTTP_RB" => :instrument_http_rb,
      "APPSIGNAL_INSTRUMENT_NET_HTTP" => :instrument_net_http,
      "APPSIGNAL_INSTRUMENT_REDIS" => :instrument_redis,
      "APPSIGNAL_INSTRUMENT_SEQUEL" => :instrument_sequel,
      "APPSIGNAL_RUNNING_IN_CONTAINER" => :running_in_container,
      "APPSIGNAL_SEND_ENVIRONMENT_METADATA" => :send_environment_metadata,
      "APPSIGNAL_SEND_PARAMS" => :send_params,
      "APPSIGNAL_SEND_SESSION_DATA" => :send_session_data,
      "APPSIGNAL_SKIP_SESSION_DATA" => :skip_session_data,
      "APPSIGNAL_TRANSACTION_DEBUG_MODE" => :transaction_debug_mode
    }.freeze
    # @api private
    ENV_ARRAY_KEYS = {
      "APPSIGNAL_DNS_SERVERS" => :dns_servers,
      "APPSIGNAL_FILTER_METADATA" => :filter_metadata,
      "APPSIGNAL_FILTER_PARAMETERS" => :filter_parameters,
      "APPSIGNAL_FILTER_SESSION_DATA" => :filter_session_data,
      "APPSIGNAL_IGNORE_ACTIONS" => :ignore_actions,
      "APPSIGNAL_IGNORE_ERRORS" => :ignore_errors,
      "APPSIGNAL_IGNORE_LOGS" => :ignore_logs,
      "APPSIGNAL_IGNORE_NAMESPACES" => :ignore_namespaces,
      "APPSIGNAL_REQUEST_HEADERS" => :request_headers
    }.freeze
    # @api private
    ENV_FLOAT_KEYS = {
      "APPSIGNAL_CPU_COUNT" => :cpu_count
    }.freeze

    # @attribute [r] system_config
    #   Config detected on the system level.
    #   Used in diagnose report.
    #   @api private
    #   @return [Hash]
    # @!attribute [r] initial_config
    #   Config detected on the system level.
    #   Used in diagnose report.
    #   @api private
    #   @return [Hash]
    # @!attribute [r] file_config
    #   Config loaded from `config/appsignal.yml` config file.
    #   Used in diagnose report.
    #   @api private
    #   @return [Hash]
    # @!attribute [r] env_config
    #   Config loaded from the system environment.
    #   Used in diagnose report.
    #   @api private
    #   @return [Hash]
    # @!attribute [r] config_hash
    #   Config used by the AppSignal gem.
    #   Combined Hash of the {system_config}, {initial_config}, {file_config},
    #   {env_config} attributes.
    #   @see #[]
    #   @see #[]=
    #   @api private
    #   @return [Hash]

    # @api private
    attr_accessor :root_path, :env, :config_hash
    attr_reader :system_config, :initial_config, :file_config, :env_config,
      :override_config, :dsl_config
    # @api private
    attr_accessor :logger

    # Initialize a new configuration object for AppSignal.
    #
    # @param root_path [String] Root path of the app.
    # @param env [String] The environment to load when AppSignal is started. It
    #   will look for an environment with this name in the `config/appsignal.yml`
    #   config file.
    # @param initial_config [Hash<String, Object>] The initial configuration to
    #   use. This will be overwritten by the file config and environment
    #   variables config.
    # @param logger [Logger] The logger to use for the AppSignal gem. This is
    #   used by the configuration class only. Default:
    #   {Appsignal.internal_logger}. See also {Appsignal.start}.
    # @param config_file [String] Custom config file location. Default
    #   `config/appsignal.yml`.
    #
    # @api private
    # @see https://docs.appsignal.com/ruby/configuration/
    #   Configuration documentation
    # @see https://docs.appsignal.com/ruby/configuration/load-order.html
    #   Configuration load order
    # @see https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html
    #   How to integrate AppSignal manually
    def initialize( # rubocop:disable Metrics/ParameterLists
      root_path,
      initial_env,
      initial_config = {},
      logger = Appsignal.internal_logger,
      config_file = nil,
      load_on_new = true # rubocop:disable Style/OptionalBooleanParameter
    )
      @root_path = root_path
      @config_file_error = false
      @config_file = config_file
      @logger = logger
      @valid = false

      @initial_env = initial_env
      @env = initial_env.to_s
      @config_hash = {}
      @system_config = {}
      @initial_config = initial_config
      @file_config = {}
      @env_config = {}
      @override_config = {}
      @dsl_config = {} # Can be set using `Appsignal.configure`

      return unless load_on_new

      # Always override environment if set via this env var.
      # TODO: This is legacy behavior. In the `Appsignal.configure` method the
      # env argument is leading.
      @env = ENV["APPSIGNAL_APP_ENV"] if ENV.key?("APPSIGNAL_APP_ENV")
      load_config
      validate
    end

    # @api private
    def load_config
      # Set defaults
      # Deep duplicate each frozen default value
      merge(DEFAULT_CONFIG.transform_values(&:dup))

      # Set config based on the system
      @system_config = detect_from_system
      merge(system_config)

      # Merge initial config
      merge(initial_config)
      # Track origin of env
      @initial_config[:env] = @initial_env.to_s

      # Load the config file if it exists
      @file_config = load_from_disk || {}
      merge(file_config)

      # Load config from environment variables
      @env_config = load_from_environment
      merge(env_config)
      # Track origin of env
      env_loaded_from_env = ENV.fetch("APPSIGNAL_APP_ENV", nil)
      @env_config[:env] = env_loaded_from_env if env_loaded_from_env

      # Load config overrides
      @override_config = determine_overrides
      merge(override_config)

      # Handle deprecated config options
      maintain_backwards_compatibility
    end

    # @api private
    # @return [String] System's tmp directory.
    def self.system_tmp_dir
      if Gem.win_platform?
        Dir.tmpdir
      else
        File.realpath("/tmp")
      end
    end

    # @api private
    def [](key)
      config_hash[key]
    end

    # Update the internal config hash.
    #
    # This method does not update the config in the extension and agent. It
    # should not be used to update the config after AppSignal has started.
    #
    # @api private
    def []=(key, value)
      config_hash[key] = value
    end

    # @api private
    def log_level
      level = ::Logger::DEBUG if config_hash[:debug] || config_hash[:transaction_debug_mode]
      option = config_hash[:log_level]
      if option
        log_level_option = LOG_LEVEL_MAP[option]
        level = log_level_option if log_level_option
      end
      level.nil? ? Appsignal::Config::DEFAULT_LOG_LEVEL : level
    end

    # @api private
    def log_file_path
      return @log_file_path if defined? @log_file_path

      path = config_hash[:log_path] || (root_path && File.join(root_path, "log"))
      if path && File.writable?(path)
        @log_file_path = File.join(File.realpath(path), "appsignal.log")
        return @log_file_path
      end

      system_tmp_dir = self.class.system_tmp_dir
      if File.writable? system_tmp_dir
        $stdout.puts "appsignal: Unable to log to '#{path}'. Logging to " \
          "'#{system_tmp_dir}' instead. " \
          "Please check the permissions for the application's (log) " \
          "directory."
        @log_file_path = File.join(system_tmp_dir, "appsignal.log")
      else
        $stdout.puts "appsignal: Unable to log to '#{path}' or the " \
          "'#{system_tmp_dir}' fallback. Please check the permissions " \
          "for the application's (log) directory."
        @log_file_path = nil
      end

      @log_file_path
    end

    def valid?
      @valid
    end

    def active?
      @valid && config_hash[:active]
    end

    # @api private
    def write_to_environment # rubocop:disable Metrics/AbcSize
      ENV["_APPSIGNAL_ACTIVE"]                       = active?.to_s
      ENV["_APPSIGNAL_AGENT_PATH"]                   = File.expand_path("../../ext", __dir__).to_s
      ENV["_APPSIGNAL_APP_NAME"]                     = config_hash[:name]
      ENV["_APPSIGNAL_APP_PATH"]                     = root_path.to_s
      ENV["_APPSIGNAL_BIND_ADDRESS"]                 = config_hash[:bind_address].to_s
      ENV["_APPSIGNAL_CA_FILE_PATH"]                 = config_hash[:ca_file_path].to_s
      ENV["_APPSIGNAL_CPU_COUNT"]                    = config_hash[:cpu_count].to_s
      ENV["_APPSIGNAL_DEBUG_LOGGING"]                = config_hash[:debug].to_s
      ENV["_APPSIGNAL_DNS_SERVERS"]                  = config_hash[:dns_servers].join(",")
      ENV["_APPSIGNAL_ENABLE_HOST_METRICS"]          = config_hash[:enable_host_metrics].to_s
      ENV["_APPSIGNAL_ENABLE_STATSD"]                = config_hash[:enable_statsd].to_s
      ENV["_APPSIGNAL_ENABLE_NGINX_METRICS"]         = config_hash[:enable_nginx_metrics].to_s
      ENV["_APPSIGNAL_APP_ENV"]                      = env
      ENV["_APPSIGNAL_FILES_WORLD_ACCESSIBLE"]       = config_hash[:files_world_accessible].to_s
      ENV["_APPSIGNAL_FILTER_PARAMETERS"]            = config_hash[:filter_parameters].join(",")
      ENV["_APPSIGNAL_FILTER_SESSION_DATA"]          = config_hash[:filter_session_data].join(",")
      ENV["_APPSIGNAL_HOSTNAME"]                     = config_hash[:hostname].to_s
      ENV["_APPSIGNAL_HOST_ROLE"]                    = config_hash[:host_role].to_s
      ENV["_APPSIGNAL_HTTP_PROXY"]                   = config_hash[:http_proxy]
      ENV["_APPSIGNAL_IGNORE_ACTIONS"]               = config_hash[:ignore_actions].join(",")
      ENV["_APPSIGNAL_IGNORE_ERRORS"]                = config_hash[:ignore_errors].join(",")
      ENV["_APPSIGNAL_IGNORE_LOGS"]                  = config_hash[:ignore_logs].join(",")
      ENV["_APPSIGNAL_IGNORE_NAMESPACES"]            = config_hash[:ignore_namespaces].join(",")
      ENV["_APPSIGNAL_LANGUAGE_INTEGRATION_VERSION"] = "ruby-#{Appsignal::VERSION}"
      ENV["_APPSIGNAL_LOG"]                          = config_hash[:log]
      ENV["_APPSIGNAL_LOG_LEVEL"]                    = config_hash[:log_level]
      ENV["_APPSIGNAL_LOG_FILE_PATH"]                = log_file_path.to_s if log_file_path
      ENV["_APPSIGNAL_LOGGING_ENDPOINT"]             = config_hash[:logging_endpoint]
      ENV["_APPSIGNAL_PROCESS_NAME"]                 = $PROGRAM_NAME
      ENV["_APPSIGNAL_PUSH_API_ENDPOINT"]            = config_hash[:endpoint]
      ENV["_APPSIGNAL_PUSH_API_KEY"]                 = config_hash[:push_api_key]
      ENV["_APPSIGNAL_RUNNING_IN_CONTAINER"]         = config_hash[:running_in_container].to_s
      ENV["_APPSIGNAL_SEND_ENVIRONMENT_METADATA"]    = config_hash[:send_environment_metadata].to_s
      ENV["_APPSIGNAL_STATSD_PORT"]                  = config_hash[:statsd_port].to_s
      ENV["_APPSIGNAL_TRANSACTION_DEBUG_MODE"]       = config_hash[:transaction_debug_mode].to_s
      if config_hash[:working_directory_path]
        ENV["_APPSIGNAL_WORKING_DIRECTORY_PATH"] = config_hash[:working_directory_path]
      end
      if config_hash[:working_dir_path]
        ENV["_APPSIGNAL_WORKING_DIR_PATH"] = config_hash[:working_dir_path]
      end
      ENV["_APP_REVISION"] = config_hash[:revision].to_s
    end

    # @api private
    def merge_dsl_options(options)
      @dsl_options = options
      merge(options)
    end

    # @api private
    def validate
      # Strip path from endpoint so we're backwards compatible with
      # earlier versions of the gem.
      # TODO: Move to its own method, maybe in `#[]=`?
      endpoint_uri = URI(config_hash[:endpoint])
      config_hash[:endpoint] =
        if endpoint_uri.port == 443
          "#{endpoint_uri.scheme}://#{endpoint_uri.host}"
        else
          "#{endpoint_uri.scheme}://#{endpoint_uri.host}:#{endpoint_uri.port}"
        end

      push_api_key = config_hash[:push_api_key] || ""
      if push_api_key.strip.empty?
        @valid = false
        @logger.error "Push API key not set after loading config"
      else
        @valid = true
      end
    end

    private

    def config_file
      @config_file ||=
        root_path.nil? ? nil : File.join(root_path, "config", "appsignal.yml")
    end

    def detect_from_system
      {}.tap do |hash|
        hash[:log] = "stdout" if Appsignal::System.heroku?

        # Make AppSignal active by default if APPSIGNAL_PUSH_API_KEY
        # environment variable is present and not empty.
        env_push_api_key = ENV["APPSIGNAL_PUSH_API_KEY"] || ""
        hash[:active] = true unless env_push_api_key.strip.empty?
      end
    end

    def load_from_disk
      return if !config_file || !File.exist?(config_file)

      read_options = YAML::VERSION >= "4.0.0" ? { :aliases => true } : {}
      configurations = YAML.load(ERB.new(File.read(config_file)).result, **read_options)
      config_for_this_env = configurations[env]
      if config_for_this_env
        config_for_this_env.transform_keys(&:to_sym)
      else
        logger.error "Not loading from config file: config for '#{env}' not found"
        nil
      end
    rescue => e
      # TODO: Remove in the next major version
      @config_file_error = true
      extra_message =
        if inactive_on_config_file_error?
          "Not starting AppSignal because " \
            "APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR is set."
        else
          "Skipping file config. In future versions AppSignal will not start " \
            "on a config file error. To opt-in to this new behavior set " \
            "'APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR=1' in your system " \
            "environment."
        end
      message = "An error occurred while loading the AppSignal config file. " \
        "#{extra_message}\n" \
        "File: #{config_file.inspect}\n" \
        "#{e.class.name}: #{e}"
      Kernel.warn "appsignal: #{message}"
      logger.error "#{message}\n#{e.backtrace.join("\n")}"
      nil
    end

    # Maintain backwards compatibility with deprecated config options.
    #
    # Add warnings for deprecated config options here if they have no
    # replacement, or should be non-functional.
    #
    # Add them to {determine_overrides} if replacement config options should be
    # set instead.
    #
    # Make sure to remove the contents of this method in the next major
    # version, but the method itself with an empty body can stick around as a
    # structure for future deprecations.
    def maintain_backwards_compatibility
      return unless config_hash.key?(:working_dir_path)

      stdout_and_logger_warning \
        "The `working_dir_path` option is deprecated, please use " \
          "`working_directory_path` instead and specify the " \
          "full path to the working directory",
        logger
    end

    def load_from_environment
      config = {}

      # Configuration with string type
      ENV_STRING_KEYS.each do |env_key, option|
        env_var = ENV.fetch(env_key, nil)
        next unless env_var

        config[option] = env_var
      end

      # Configuration with boolean type
      ENV_BOOLEAN_KEYS.each do |env_key, option|
        env_var = ENV.fetch(env_key, nil)
        next unless env_var

        config[option] = env_var.casecmp("true").zero?
      end

      # Configuration with array of strings type
      ENV_ARRAY_KEYS.each do |env_key, option|
        env_var = ENV.fetch(env_key, nil)
        next unless env_var

        config[option] = env_var.split(",")
      end

      # Configuration with float type
      ENV_FLOAT_KEYS.each do |env_key, option|
        env_var = ENV.fetch(env_key, nil)
        next unless env_var

        config[option] = env_var.to_f
      end

      config
    end

    # Set config options based on the final user config. Fix any conflicting
    # config or set new config options based on deprecated config options.
    #
    # Make sure to remove behavior for deprecated config options in this method
    # in the next major version, but the method itself with an empty body can
    # stick around as a structure for future deprecations.
    def determine_overrides
      config = {}
      # If an error was detected during config file reading/parsing and the new
      # behavior is enabled to not start AppSignal on incomplete config, do not
      # start AppSignal.
      # TODO: Make default behavior in next major version. Remove
      # `inactive_on_config_file_error?` call.
      config[:active] = false if @config_file_error && inactive_on_config_file_error?
      skip_session_data = config_hash[:skip_session_data]
      send_session_data = config_hash[:send_session_data]
      if skip_session_data.nil? # Deprecated option is not set
        if send_session_data.nil? # Not configured by user
          config[:send_session_data] = true # Set default value
        end
      else
        stdout_and_logger_warning "The `skip_session_data` config option is " \
          "deprecated. Please use `send_session_data` instead.",
          logger
        # Not configured by user
        config[:send_session_data] = !skip_session_data if send_session_data.nil?
      end

      if config_hash[:activejob_report_errors] == "discard" &&
          !Appsignal::Hooks::ActiveJobHook.version_7_1_or_higher?
        config[:activejob_report_errors] = "all"
      end

      if config_hash[:sidekiq_report_errors] == "discard" &&
          !Appsignal::Hooks::SidekiqHook.version_5_1_or_higher?
        config[:sidekiq_report_errors] = "all"
      end

      config
    end

    def merge(new_config)
      new_config.each do |key, value|
        @logger.debug("Config key '#{key}' is being overwritten") unless config_hash[key].nil?
        config_hash[key] = value
      end
    end

    # Does it use the new behavior?
    def inactive_on_config_file_error?
      value = ENV.fetch("APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR", false)
      ["1", "true"].include?(value)
    end

    # @api private
    class ConfigDSL
      attr_reader :dsl_options

      def initialize(config)
        @config = config
        @dsl_options = {}
      end

      def app_path
        @config.root_path
      end

      def app_path=(_path)
        Appsignal::Utils::StdoutAndLoggerMessage.warning \
          "The `Appsignal.configure`'s `app_path=` writer is deprecated. " \
            "Use the `Appsignal.configure`'s method `path` keyword argument " \
            "to set the root path."
      end

      def env
        @config.env
      end

      Appsignal::Config::ENV_STRING_KEYS.each_value do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, value.to_s)
        end
      end

      Appsignal::Config::ENV_BOOLEAN_KEYS.each_value do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, !!value)
        end
      end

      Appsignal::Config::ENV_ARRAY_KEYS.each_value do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, value.to_a)
        end
      end

      Appsignal::Config::ENV_FLOAT_KEYS.each_value do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, value.to_f)
        end
      end

      private

      def fetch_option(key)
        if @dsl_options.key?(key)
          @dsl_options[key]
        else
          @dsl_options[key] = @config[key].dup
        end
      end

      def update_option(key, value)
        @dsl_options[key] = value
      end
    end
  end
end
