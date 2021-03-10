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
      :debug                          => false,
      :log                            => "file",
      :ignore_actions                 => [],
      :ignore_errors                  => [],
      :ignore_namespaces              => [],
      :filter_parameters              => [],
      :filter_session_data            => [],
      :send_environment_metadata      => true,
      :send_params                    => true,
      :request_headers                => %w[
        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_CONNECTION
        CONTENT_LENGTH PATH_INFO HTTP_RANGE
        REQUEST_METHOD REQUEST_URI SERVER_NAME SERVER_PORT
        SERVER_PROTOCOL
      ],
      :endpoint                       => "https://push.appsignal.com",
      :instrument_net_http            => true,
      :instrument_redis               => true,
      :instrument_sequel              => true,
      :skip_session_data              => false,
      :enable_allocation_tracking     => true,
      :enable_gc_instrumentation      => false,
      :enable_host_metrics            => true,
      :enable_minutely_probes         => true,
      :ca_file_path                   => File.expand_path(File.join("../../../resources/cacert.pem"), __FILE__),
      :dns_servers                    => [],
      :files_world_accessible         => true,
      :transaction_debug_mode         => false
    }.freeze

    ENV_TO_KEY_MAPPING = {
      "APPSIGNAL_ACTIVE"                         => :active,
      "APPSIGNAL_PUSH_API_KEY"                   => :push_api_key,
      "APPSIGNAL_APP_NAME"                       => :name,
      "APPSIGNAL_PUSH_API_ENDPOINT"              => :endpoint,
      "APPSIGNAL_DEBUG"                          => :debug,
      "APPSIGNAL_LOG"                            => :log,
      "APPSIGNAL_LOG_PATH"                       => :log_path,
      "APPSIGNAL_INSTRUMENT_NET_HTTP"            => :instrument_net_http,
      "APPSIGNAL_INSTRUMENT_REDIS"               => :instrument_redis,
      "APPSIGNAL_INSTRUMENT_SEQUEL"              => :instrument_sequel,
      "APPSIGNAL_SKIP_SESSION_DATA"              => :skip_session_data,
      "APPSIGNAL_IGNORE_ACTIONS"                 => :ignore_actions,
      "APPSIGNAL_IGNORE_ERRORS"                  => :ignore_errors,
      "APPSIGNAL_IGNORE_NAMESPACES"              => :ignore_namespaces,
      "APPSIGNAL_FILTER_PARAMETERS"              => :filter_parameters,
      "APPSIGNAL_FILTER_SESSION_DATA"            => :filter_session_data,
      "APPSIGNAL_SEND_ENVIRONMENT_METADATA"      => :send_environment_metadata,
      "APPSIGNAL_SEND_PARAMS"                    => :send_params,
      "APPSIGNAL_HTTP_PROXY"                     => :http_proxy,
      "APPSIGNAL_ENABLE_ALLOCATION_TRACKING"     => :enable_allocation_tracking,
      "APPSIGNAL_ENABLE_GC_INSTRUMENTATION"      => :enable_gc_instrumentation,
      "APPSIGNAL_RUNNING_IN_CONTAINER"           => :running_in_container,
      "APPSIGNAL_WORKING_DIR_PATH"               => :working_dir_path,
      "APPSIGNAL_WORKING_DIRECTORY_PATH"         => :working_directory_path,
      "APPSIGNAL_ENABLE_HOST_METRICS"            => :enable_host_metrics,
      "APPSIGNAL_ENABLE_MINUTELY_PROBES"         => :enable_minutely_probes,
      "APPSIGNAL_HOSTNAME"                       => :hostname,
      "APPSIGNAL_CA_FILE_PATH"                   => :ca_file_path,
      "APPSIGNAL_DNS_SERVERS"                    => :dns_servers,
      "APPSIGNAL_FILES_WORLD_ACCESSIBLE"         => :files_world_accessible,
      "APPSIGNAL_REQUEST_HEADERS"                => :request_headers,
      "APPSIGNAL_TRANSACTION_DEBUG_MODE"         => :transaction_debug_mode,
      "APP_REVISION"                             => :revision
    }.freeze
    # @api private
    ENV_STRING_KEYS = %w[
      APPSIGNAL_APP_NAME
      APPSIGNAL_CA_FILE_PATH
      APPSIGNAL_HOSTNAME
      APPSIGNAL_HTTP_PROXY
      APPSIGNAL_LOG
      APPSIGNAL_LOG_PATH
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
      APPSIGNAL_ENABLE_GC_INSTRUMENTATION
      APPSIGNAL_ENABLE_HOST_METRICS
      APPSIGNAL_ENABLE_MINUTELY_PROBES
      APPSIGNAL_FILES_WORLD_ACCESSIBLE
      APPSIGNAL_INSTRUMENT_NET_HTTP
      APPSIGNAL_INSTRUMENT_REDIS
      APPSIGNAL_INSTRUMENT_SEQUEL
      APPSIGNAL_RUNNING_IN_CONTAINER
      APPSIGNAL_SEND_ENVIRONMENT_METADATA
      APPSIGNAL_SEND_PARAMS
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
      :initial_config, :file_config, :env_config
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
    def initialize(root_path, env, initial_config = {}, logger = Appsignal.logger, config_file = nil)
      @root_path      = root_path
      @config_file    = config_file
      @logger         = logger
      @valid          = false
      @config_hash    = Hash[DEFAULT_CONFIG]
      env_loaded_from_initial = env.to_s
      @env =
        if ENV.key?("APPSIGNAL_APP_ENV".freeze)
          env_loaded_from_env = ENV["APPSIGNAL_APP_ENV".freeze]
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

    def log_file_path
      path = config_hash[:log_path] || root_path && File.join(root_path, "log")
      if path && File.writable?(path)
        return File.join(File.realpath(path), "appsignal.log")
      end

      system_tmp_dir = self.class.system_tmp_dir
      if File.writable? system_tmp_dir
        $stdout.puts "appsignal: Unable to log to '#{path}'. Logging to "\
          "'#{system_tmp_dir}' instead. Please check the "\
          "permissions for the application's (log) directory."
        File.join(system_tmp_dir, "appsignal.log")
      else
        $stdout.puts "appsignal: Unable to log to '#{path}' or the "\
          "'#{system_tmp_dir}' fallback. Please check the permissions "\
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
      ENV["_APPSIGNAL_APP_PATH"]                     = root_path.to_s
      ENV["_APPSIGNAL_AGENT_PATH"]                   = File.expand_path("../../../ext", __FILE__).to_s
      ENV["_APPSIGNAL_ENVIRONMENT"]                  = env
      ENV["_APPSIGNAL_LANGUAGE_INTEGRATION_VERSION"] = "ruby-#{Appsignal::VERSION}"
      ENV["_APPSIGNAL_DEBUG_LOGGING"]                = config_hash[:debug].to_s
      ENV["_APPSIGNAL_LOG"]                          = config_hash[:log]
      ENV["_APPSIGNAL_LOG_FILE_PATH"]                = log_file_path.to_s if log_file_path
      ENV["_APPSIGNAL_PUSH_API_ENDPOINT"]            = config_hash[:endpoint]
      ENV["_APPSIGNAL_PUSH_API_KEY"]                 = config_hash[:push_api_key]
      ENV["_APPSIGNAL_APP_NAME"]                     = config_hash[:name]
      ENV["_APPSIGNAL_HTTP_PROXY"]                   = config_hash[:http_proxy]
      ENV["_APPSIGNAL_IGNORE_ACTIONS"]               = config_hash[:ignore_actions].join(",")
      ENV["_APPSIGNAL_IGNORE_ERRORS"]                = config_hash[:ignore_errors].join(",")
      ENV["_APPSIGNAL_IGNORE_NAMESPACES"]            = config_hash[:ignore_namespaces].join(",")
      ENV["_APPSIGNAL_RUNNING_IN_CONTAINER"]         = config_hash[:running_in_container].to_s
      ENV["_APPSIGNAL_WORKING_DIR_PATH"]             = config_hash[:working_dir_path] if config_hash[:working_dir_path]
      ENV["_APPSIGNAL_WORKING_DIRECTORY_PATH"]       = config_hash[:working_directory_path] if config_hash[:working_directory_path]
      ENV["_APPSIGNAL_ENABLE_HOST_METRICS"]          = config_hash[:enable_host_metrics].to_s
      ENV["_APPSIGNAL_HOSTNAME"]                     = config_hash[:hostname].to_s
      ENV["_APPSIGNAL_PROCESS_NAME"]                 = $PROGRAM_NAME
      ENV["_APPSIGNAL_CA_FILE_PATH"]                 = config_hash[:ca_file_path].to_s
      ENV["_APPSIGNAL_DNS_SERVERS"]                  = config_hash[:dns_servers].join(",")
      ENV["_APPSIGNAL_FILES_WORLD_ACCESSIBLE"]       = config_hash[:files_world_accessible].to_s
      ENV["_APPSIGNAL_TRANSACTION_DEBUG_MODE"]       = config_hash[:transaction_debug_mode].to_s
      ENV["_APPSIGNAL_SEND_ENVIRONMENT_METADATA"]    = config_hash[:send_environment_metadata].to_s
      ENV["_APP_REVISION"]                           = config_hash[:revision].to_s
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

      configurations = YAML.load(ERB.new(IO.read(config_file)).result)
      config_for_this_env = configurations[env]
      if config_for_this_env
        config_for_this_env =
          config_for_this_env.each_with_object({}) do |(key, value), hash|
            hash[key.to_sym] = value # convert keys to symbols
          end

        maintain_backwards_compatibility(config_for_this_env)
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

    # Maintain backwards compatibility with config files generated by earlier
    # versions of the gem
    #
    # Used by {#load_from_disk}. No compatibility for env variables or initial config currently.
    def maintain_backwards_compatibility(configuration)
      configuration.tap do |config|
        if config.include?(:working_dir_path)
          deprecation_message \
            "'working_dir_path' is deprecated, please use " \
            "'working_directory_path' instead and specify the " \
            "full path to the working directory",
            logger
        end
      end
    end

    def load_from_environment
      config = {}

      # Configuration with string type
      ENV_STRING_KEYS.each do |var|
        env_var = ENV[var]
        next unless env_var
        config[ENV_TO_KEY_MAPPING[var]] = env_var
      end

      # Configuration with boolean type
      ENV_BOOLEAN_KEYS.each do |var|
        env_var = ENV[var]
        next unless env_var
        config[ENV_TO_KEY_MAPPING[var]] = env_var.casecmp("true").zero?
      end

      # Configuration with array of strings type
      ENV_ARRAY_KEYS.each do |var|
        env_var = ENV[var]
        next unless env_var
        config[ENV_TO_KEY_MAPPING[var]] = env_var.split(",")
      end

      config
    end

    def merge(new_config)
      new_config.each do |key, value|
        unless config_hash[key].nil?
          @logger.debug("Config key '#{key}' is being overwritten")
        end
        config_hash[key] = value
      end
    end
  end
end
