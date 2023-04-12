# frozen_string_literal: true

require "erb"
require "yaml"
require "uri"
require "socket"
require "tmpdir"

module Appsignal
  class Config
    include Appsignal::Utils::DeprecationMessage

    DEFAULT_CONFIG = {
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
      :endpoint => "https://push.appsignal.com",
      :files_world_accessible => true,
      :filter_parameters => [],
      :filter_session_data => [],
      :ignore_actions => [],
      :ignore_errors => [],
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
        REQUEST_METHOD REQUEST_URI SERVER_NAME SERVER_PORT
        SERVER_PROTOCOL
      ],
      :send_environment_metadata => true,
      :send_params => true,
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

    ENV_TO_KEY_MAPPING = {
      "APPSIGNAL_ACTIVE" => :active,
      "APPSIGNAL_APP_NAME" => :name,
      "APPSIGNAL_CA_FILE_PATH" => :ca_file_path,
      "APPSIGNAL_DEBUG" => :debug,
      "APPSIGNAL_DNS_SERVERS" => :dns_servers,
      "APPSIGNAL_ENABLE_ALLOCATION_TRACKING" => :enable_allocation_tracking,
      "APPSIGNAL_ENABLE_HOST_METRICS" => :enable_host_metrics,
      "APPSIGNAL_ENABLE_MINUTELY_PROBES" => :enable_minutely_probes,
      "APPSIGNAL_ENABLE_STATSD" => :enable_statsd,
      "APPSIGNAL_ENABLE_NGINX_METRICS" => :enable_nginx_metrics,
      "APPSIGNAL_ENABLE_GVL_GLOBAL_TIMER" => :enable_gvl_global_timer,
      "APPSIGNAL_ENABLE_GVL_WAITING_THREADS" => :enable_gvl_waiting_threads,
      "APPSIGNAL_ENABLE_RAILS_ERROR_REPORTER" => :enable_rails_error_reporter,
      "APPSIGNAL_FILES_WORLD_ACCESSIBLE" => :files_world_accessible,
      "APPSIGNAL_FILTER_PARAMETERS" => :filter_parameters,
      "APPSIGNAL_FILTER_SESSION_DATA" => :filter_session_data,
      "APPSIGNAL_HOSTNAME" => :hostname,
      "APPSIGNAL_HTTP_PROXY" => :http_proxy,
      "APPSIGNAL_IGNORE_ACTIONS" => :ignore_actions,
      "APPSIGNAL_IGNORE_ERRORS" => :ignore_errors,
      "APPSIGNAL_IGNORE_NAMESPACES" => :ignore_namespaces,
      "APPSIGNAL_INSTRUMENT_HTTP_RB" => :instrument_http_rb,
      "APPSIGNAL_INSTRUMENT_NET_HTTP" => :instrument_net_http,
      "APPSIGNAL_INSTRUMENT_REDIS" => :instrument_redis,
      "APPSIGNAL_INSTRUMENT_SEQUEL" => :instrument_sequel,
      "APPSIGNAL_LOG" => :log,
      "APPSIGNAL_LOG_LEVEL" => :log_level,
      "APPSIGNAL_LOG_PATH" => :log_path,
      "APPSIGNAL_LOGGING_ENDPOINT" => :logging_endpoint,
      "APPSIGNAL_PUSH_API_ENDPOINT" => :endpoint,
      "APPSIGNAL_PUSH_API_KEY" => :push_api_key,
      "APPSIGNAL_REQUEST_HEADERS" => :request_headers,
      "APPSIGNAL_RUNNING_IN_CONTAINER" => :running_in_container,
      "APPSIGNAL_SEND_ENVIRONMENT_METADATA" => :send_environment_metadata,
      "APPSIGNAL_SEND_PARAMS" => :send_params,
      "APPSIGNAL_SEND_SESSION_DATA" => :send_session_data,
      "APPSIGNAL_SKIP_SESSION_DATA" => :skip_session_data,
      "APPSIGNAL_TRANSACTION_DEBUG_MODE" => :transaction_debug_mode,
      "APPSIGNAL_WORKING_DIRECTORY_PATH" => :working_directory_path,
      "APPSIGNAL_WORKING_DIR_PATH" => :working_dir_path,
      "APP_REVISION" => :revision
    }.freeze
    # @api private
    ENV_STRING_KEYS = %w[
      APPSIGNAL_APP_NAME
      APPSIGNAL_CA_FILE_PATH
      APPSIGNAL_HOSTNAME
      APPSIGNAL_HTTP_PROXY
      APPSIGNAL_LOG
      APPSIGNAL_LOG_LEVEL
      APPSIGNAL_LOG_PATH
      APPSIGNAL_LOGGING_ENDPOINT
      APPSIGNAL_PUSH_API_ENDPOINT
      APPSIGNAL_PUSH_API_KEY
      APPSIGNAL_WORKING_DIRECTORY_PATH
      APPSIGNAL_WORKING_DIR_PATH
      APP_REVISION
    ].freeze
    # @api private
    ENV_BOOLEAN_KEYS = %w[
      APPSIGNAL_ACTIVE
      APPSIGNAL_DEBUG
      APPSIGNAL_ENABLE_ALLOCATION_TRACKING
      APPSIGNAL_ENABLE_HOST_METRICS
      APPSIGNAL_ENABLE_MINUTELY_PROBES
      APPSIGNAL_ENABLE_STATSD
      APPSIGNAL_ENABLE_NGINX_METRICS
      APPSIGNAL_ENABLE_GVL_GLOBAL_TIMER
      APPSIGNAL_ENABLE_GVL_WAITING_THREADS
      APPSIGNAL_ENABLE_RAILS_ERROR_REPORTER
      APPSIGNAL_FILES_WORLD_ACCESSIBLE
      APPSIGNAL_INSTRUMENT_HTTP_RB
      APPSIGNAL_INSTRUMENT_NET_HTTP
      APPSIGNAL_INSTRUMENT_REDIS
      APPSIGNAL_INSTRUMENT_SEQUEL
      APPSIGNAL_RUNNING_IN_CONTAINER
      APPSIGNAL_SEND_ENVIRONMENT_METADATA
      APPSIGNAL_SEND_PARAMS
      APPSIGNAL_SEND_SESSION_DATA
      APPSIGNAL_SKIP_SESSION_DATA
      APPSIGNAL_TRANSACTION_DEBUG_MODE
    ].freeze
    # @api private
    ENV_ARRAY_KEYS = %w[
      APPSIGNAL_DNS_SERVERS
      APPSIGNAL_FILTER_PARAMETERS
      APPSIGNAL_FILTER_SESSION_DATA
      APPSIGNAL_IGNORE_ACTIONS
      APPSIGNAL_IGNORE_ERRORS
      APPSIGNAL_IGNORE_NAMESPACES
      APPSIGNAL_REQUEST_HEADERS
    ].freeze

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

    attr_reader :root_path, :env, :config_hash, :system_config,
      :initial_config, :file_config, :env_config, :override_config
    attr_accessor :logger

    # Initialize a new configuration object for AppSignal.
    #
    # If this is manually initialized, and not by {Appsignal.start}, it needs
    # to be assigned to the {Appsignal.config} attribute.
    #
    # @example
    #   require "appsignal"
    #   Appsignal.config = Appsignal::Config.new(
    #     app_path,
    #     "production"
    #   )
    #   Appsignal.start
    #
    # @param root_path [String] Root path of the app.
    # @param env [String] The environment to load when AppSignal is started. It
    #   will look for an environment with this name in the `config/appsignal.yml`
    #   config file.
    # @param initial_config [Hash<String, Object>] The initial configuration to
    #   use. This will be overwritten by the file config and environment
    #   variables config.
    # @param logger [Logger] The logger to use for the AppSignal gem. This is
    #   used by the configuration class only. Default: {Appsignal.logger}. See
    #   also {Appsignal.start_logger}.
    # @param config_file [String] Custom config file location. Default
    #   `config/appsignal.yml`.
    #
    # @see https://docs.appsignal.com/ruby/configuration/
    #   Configuration documentation
    # @see https://docs.appsignal.com/ruby/configuration/load-order.html
    #   Configuration load order
    # @see https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html
    #   How to integrate AppSignal manually
    def initialize(root_path, env, initial_config = {}, logger = Appsignal.logger,
      config_file = nil)
      @root_path = root_path
      @config_file = config_file
      @logger = logger
      @valid = false
      @config_hash = DEFAULT_CONFIG.dup
      env_loaded_from_initial = env.to_s
      @env =
        if ENV.key?("APPSIGNAL_APP_ENV")
          env_loaded_from_env = ENV["APPSIGNAL_APP_ENV"]
        else
          env_loaded_from_initial
        end

      # Set config based on the system
      @system_config = detect_from_system
      merge(system_config)
      # Initial config
      @initial_config = initial_config
      merge(initial_config)
      # Load the config file if it exists
      @file_config = load_from_disk || {}
      merge(file_config)
      # Load config from environment variables
      @env_config = load_from_environment
      merge(env_config)
      # Load config overrides
      @override_config = determine_overrides
      merge(override_config)
      # Handle deprecated config options
      maintain_backwards_compatibility
      # Validate that we have a correct config
      validate
      # Track origin of env
      @initial_config[:env] = env_loaded_from_initial if env_loaded_from_initial
      @env_config[:env] = env_loaded_from_env if env_loaded_from_env
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

    def [](key)
      config_hash[key]
    end

    def []=(key, value)
      config_hash[key] = value
    end

    def log_level
      level = ::Logger::DEBUG if config_hash[:debug] || config_hash[:transaction_debug_mode]
      option = config_hash[:log_level]
      if option
        log_level_option = LOG_LEVEL_MAP[option]
        level = log_level_option if log_level_option
      end
      level.nil? ? Appsignal::Config::DEFAULT_LOG_LEVEL : level
    end

    def log_file_path
      path = config_hash[:log_path] || (root_path && File.join(root_path, "log"))
      return File.join(File.realpath(path), "appsignal.log") if path && File.writable?(path)

      system_tmp_dir = self.class.system_tmp_dir
      if File.writable? system_tmp_dir
        $stdout.puts "appsignal: Unable to log to '#{path}'. Logging to " \
          "'#{system_tmp_dir}' instead. Please check the " \
          "permissions for the application's (log) directory."
        File.join(system_tmp_dir, "appsignal.log")
      else
        $stdout.puts "appsignal: Unable to log to '#{path}' or the " \
          "'#{system_tmp_dir}' fallback. Please check the permissions " \
          "for the application's (log) directory."
      end
    end

    def valid?
      @valid
    end

    def active?
      @valid && config_hash[:active]
    end

    def write_to_environment # rubocop:disable Metrics/AbcSize
      ENV["_APPSIGNAL_ACTIVE"]                       = active?.to_s
      ENV["_APPSIGNAL_AGENT_PATH"]                   = File.expand_path("../../ext", __dir__).to_s
      ENV["_APPSIGNAL_APP_NAME"]                     = config_hash[:name]
      ENV["_APPSIGNAL_APP_PATH"]                     = root_path.to_s
      ENV["_APPSIGNAL_CA_FILE_PATH"]                 = config_hash[:ca_file_path].to_s
      ENV["_APPSIGNAL_DEBUG_LOGGING"]                = config_hash[:debug].to_s
      ENV["_APPSIGNAL_DNS_SERVERS"]                  = config_hash[:dns_servers].join(",")
      ENV["_APPSIGNAL_ENABLE_HOST_METRICS"]          = config_hash[:enable_host_metrics].to_s
      ENV["_APPSIGNAL_ENABLE_STATSD"]                = config_hash[:enable_statsd].to_s
      ENV["_APPSIGNAL_ENABLE_NGINX_METRICS"]         = config_hash[:enable_nginx_metrics].to_s
      ENV["_APPSIGNAL_ENVIRONMENT"]                  = env
      ENV["_APPSIGNAL_FILES_WORLD_ACCESSIBLE"]       = config_hash[:files_world_accessible].to_s
      ENV["_APPSIGNAL_FILTER_PARAMETERS"]            = config_hash[:filter_parameters].join(",")
      ENV["_APPSIGNAL_FILTER_SESSION_DATA"]          = config_hash[:filter_session_data].join(",")
      ENV["_APPSIGNAL_HOSTNAME"]                     = config_hash[:hostname].to_s
      ENV["_APPSIGNAL_HTTP_PROXY"]                   = config_hash[:http_proxy]
      ENV["_APPSIGNAL_IGNORE_ACTIONS"]               = config_hash[:ignore_actions].join(",")
      ENV["_APPSIGNAL_IGNORE_ERRORS"]                = config_hash[:ignore_errors].join(",")
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
      ENV["_APPSIGNAL_TRANSACTION_DEBUG_MODE"]       = config_hash[:transaction_debug_mode].to_s
      if config_hash[:working_directory_path]
        ENV["_APPSIGNAL_WORKING_DIRECTORY_PATH"] = config_hash[:working_directory_path]
      end
      if config_hash[:working_dir_path]
        ENV["_APPSIGNAL_WORKING_DIR_PATH"] = config_hash[:working_dir_path]
      end
      ENV["_APP_REVISION"] = config_hash[:revision].to_s
    end

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
      message = "An error occured while loading the AppSignal config file." \
        " Skipping file config.\n" \
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

      deprecation_message \
        "The `working_dir_path` option is deprecated, please use " \
          "`working_directory_path` instead and specify the " \
          "full path to the working directory",
        logger
    end

    def load_from_environment
      config = {}

      # Configuration with string type
      ENV_STRING_KEYS.each do |var|
        env_var = ENV.fetch(var, nil)
        next unless env_var

        config[ENV_TO_KEY_MAPPING[var]] = env_var
      end

      # Configuration with boolean type
      ENV_BOOLEAN_KEYS.each do |var|
        env_var = ENV.fetch(var, nil)
        next unless env_var

        config[ENV_TO_KEY_MAPPING[var]] = env_var.casecmp("true").zero?
      end

      # Configuration with array of strings type
      ENV_ARRAY_KEYS.each do |var|
        env_var = ENV.fetch(var, nil)
        next unless env_var

        config[ENV_TO_KEY_MAPPING[var]] = env_var.split(",")
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
      skip_session_data = config_hash[:skip_session_data]
      send_session_data = config_hash[:send_session_data]
      if skip_session_data.nil? # Deprecated option is not set
        if send_session_data.nil? # Not configured by user
          config[:send_session_data] = true # Set default value
        end
      else
        deprecation_message "The `skip_session_data` config option is " \
          "deprecated. Please use `send_session_data` instead.",
          logger
        # Not configured by user
        config[:send_session_data] = !skip_session_data if send_session_data.nil?
      end

      config
    end

    def merge(new_config)
      new_config.each do |key, value|
        @logger.debug("Config key '#{key}' is being overwritten") unless config_hash[key].nil?
        config_hash[key] = value
      end
    end
  end
end
