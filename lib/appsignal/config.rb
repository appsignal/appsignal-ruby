# frozen_string_literal: true

require "erb"
require "yaml"
require "uri"
require "socket"
require "tmpdir"

module Appsignal
  class Config
    # @!visibility private
    def self.loader_defaults
      @loader_defaults ||= []
    end

    # @!visibility private
    def self.add_loader_defaults(name, env: nil, root_path: nil, **options)
      if Appsignal.config
        Appsignal.internal_logger.warn(
          "The config defaults from the '#{name}' loader are ignored since " \
            "the AppSignal config has already been initialized."
        )
      end

      loader_defaults << {
        :name => name,
        :env => env,
        :root_path => root_path,
        :options => options.compact
      }
    end

    # Determine which env AppSignal should initialize with.
    # @!visibility private
    def self.determine_env(initial_env = nil)
      [
        initial_env,
        ENV.fetch("_APPSIGNAL_CONFIG_FILE_ENV", nil), # PRIVATE ENV var used by the diagnose CLI
        ENV.fetch("APPSIGNAL_APP_ENV", nil),
        ENV.fetch("RAILS_ENV", nil),
        ENV.fetch("RACK_ENV", nil)
      ].compact.each do |env_value|
        value = env_value.to_s.strip
        next if value.empty?
        return value if value
      end

      loader_defaults.reverse.each do |loader_defaults|
        env = loader_defaults[:env]
        return env if env
      end

      nil
    end

    # Determine which root path AppSignal should initialize with.
    # @!visibility private
    def self.determine_root_path
      app_path_env_var = ENV.fetch("APPSIGNAL_APP_PATH", nil)
      return app_path_env_var if app_path_env_var

      loader_defaults.reverse.each do |loader_defaults|
        root_path = loader_defaults[:root_path]
        return root_path if root_path
      end

      Dir.pwd
    end

    # @!visibility private
    class Context
      DSL_FILENAME = "config/appsignal.rb"

      attr_reader :env, :root_path

      def initialize(env: nil, root_path: nil)
        @env = env
        @root_path = root_path
      end

      def dsl_config_file
        File.join(root_path, DSL_FILENAME)
      end

      def dsl_config_file?
        File.exist?(dsl_config_file)
      end
    end

    # @!visibility private
    DEFAULT_CONFIG = {
      :activejob_report_errors => "all",
      :ca_file_path => File.expand_path(File.join("../../../resources/cacert.pem"), __FILE__),
      :dns_servers => [],
      :enable_allocation_tracking => true,
      :enable_at_exit_hook => "on_error",
      :enable_at_exit_reporter => true,
      :enable_host_metrics => true,
      :enable_minutely_probes => true,
      :enable_statsd => true,
      :enable_nginx_metrics => false,
      :enable_gvl_global_timer => true,
      :enable_gvl_waiting_threads => true,
      :enable_rails_error_reporter => true,
      :enable_active_support_event_log_reporter => false,
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
      :instrument_code_ownership => true,
      :instrument_http_rb => true,
      :instrument_net_http => true,
      :instrument_ownership => true,
      :instrument_redis => true,
      :instrument_sequel => true,
      :log => "file",
      :logging_endpoint => "https://appsignal-endpoint.net",
      :ownership_set_namespace => false,
      :request_headers => %w[
        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_CONNECTION
        CONTENT_LENGTH PATH_INFO HTTP_RANGE
        REQUEST_METHOD REQUEST_PATH SERVER_NAME SERVER_PORT
        SERVER_PROTOCOL
      ],
      :send_environment_metadata => true,
      :send_params => true,
      :send_session_data => true,
      :sidekiq_report_errors => "all"
    }.freeze

    # @!visibility private
    DEFAULT_LOG_LEVEL = ::Logger::INFO
    # Map from the `log_level` config option to Ruby's Logger level value.
    #
    # The trace level doesn't exist in the Ruby logger so it's mapped to debug.
    # @!visibility private
    LOG_LEVEL_MAP = {
      "error" => ::Logger::ERROR,
      "warn" => ::Logger::WARN,
      "warning" => ::Logger::WARN,
      "info" => ::Logger::INFO,
      "debug" => ::Logger::DEBUG,
      "trace" => ::Logger::DEBUG
    }.freeze

    # @!visibility private
    STRING_OPTIONS = {
      :activejob_report_errors => "APPSIGNAL_ACTIVEJOB_REPORT_ERRORS",
      :name => "APPSIGNAL_APP_NAME",
      :bind_address => "APPSIGNAL_BIND_ADDRESS",
      :ca_file_path => "APPSIGNAL_CA_FILE_PATH",
      :enable_at_exit_hook => "APPSIGNAL_ENABLE_AT_EXIT_HOOK",
      :hostname => "APPSIGNAL_HOSTNAME",
      :host_role => "APPSIGNAL_HOST_ROLE",
      :http_proxy => "APPSIGNAL_HTTP_PROXY",
      :log => "APPSIGNAL_LOG",
      :log_level => "APPSIGNAL_LOG_LEVEL",
      :log_path => "APPSIGNAL_LOG_PATH",
      :logging_endpoint => "APPSIGNAL_LOGGING_ENDPOINT",
      :endpoint => "APPSIGNAL_PUSH_API_ENDPOINT",
      :push_api_key => "APPSIGNAL_PUSH_API_KEY",
      :sidekiq_report_errors => "APPSIGNAL_SIDEKIQ_REPORT_ERRORS",
      :statsd_port => "APPSIGNAL_STATSD_PORT",
      :nginx_port => "APPSIGNAL_NGINX_PORT",
      :working_directory_path => "APPSIGNAL_WORKING_DIRECTORY_PATH",
      :revision => "APP_REVISION"
    }.freeze

    # @!visibility private
    BOOLEAN_OPTIONS = {
      :active => "APPSIGNAL_ACTIVE",
      :enable_allocation_tracking => "APPSIGNAL_ENABLE_ALLOCATION_TRACKING",
      :enable_at_exit_reporter => "APPSIGNAL_ENABLE_AT_EXIT_REPORTER",
      :enable_host_metrics => "APPSIGNAL_ENABLE_HOST_METRICS",
      :enable_minutely_probes => "APPSIGNAL_ENABLE_MINUTELY_PROBES",
      :enable_statsd => "APPSIGNAL_ENABLE_STATSD",
      :enable_nginx_metrics => "APPSIGNAL_ENABLE_NGINX_METRICS",
      :enable_gvl_global_timer => "APPSIGNAL_ENABLE_GVL_GLOBAL_TIMER",
      :enable_gvl_waiting_threads => "APPSIGNAL_ENABLE_GVL_WAITING_THREADS",
      :enable_rails_error_reporter => "APPSIGNAL_ENABLE_RAILS_ERROR_REPORTER",
      :enable_active_support_event_log_reporter =>
        "APPSIGNAL_ENABLE_ACTIVE_SUPPORT_EVENT_LOG_REPORTER",
      :enable_rake_performance_instrumentation =>
        "APPSIGNAL_ENABLE_RAKE_PERFORMANCE_INSTRUMENTATION",
      :files_world_accessible => "APPSIGNAL_FILES_WORLD_ACCESSIBLE",
      :instrument_code_ownership => "APPSIGNAL_INSTRUMENT_CODE_OWNERSHIP",
      :instrument_http_rb => "APPSIGNAL_INSTRUMENT_HTTP_RB",
      :instrument_net_http => "APPSIGNAL_INSTRUMENT_NET_HTTP",
      :instrument_ownership => "APPSIGNAL_INSTRUMENT_OWNERSHIP",
      :instrument_redis => "APPSIGNAL_INSTRUMENT_REDIS",
      :instrument_sequel => "APPSIGNAL_INSTRUMENT_SEQUEL",
      :ownership_set_namespace => "APPSIGNAL_OWNERSHIP_SET_NAMESPACE",
      :running_in_container => "APPSIGNAL_RUNNING_IN_CONTAINER",
      :send_environment_metadata => "APPSIGNAL_SEND_ENVIRONMENT_METADATA",
      :send_params => "APPSIGNAL_SEND_PARAMS",
      :send_session_data => "APPSIGNAL_SEND_SESSION_DATA"
    }.freeze

    # @!visibility private
    ARRAY_OPTIONS = {
      :dns_servers => "APPSIGNAL_DNS_SERVERS",
      :filter_metadata => "APPSIGNAL_FILTER_METADATA",
      :filter_parameters => "APPSIGNAL_FILTER_PARAMETERS",
      :filter_session_data => "APPSIGNAL_FILTER_SESSION_DATA",
      :ignore_actions => "APPSIGNAL_IGNORE_ACTIONS",
      :ignore_errors => "APPSIGNAL_IGNORE_ERRORS",
      :ignore_logs => "APPSIGNAL_IGNORE_LOGS",
      :ignore_namespaces => "APPSIGNAL_IGNORE_NAMESPACES",
      :request_headers => "APPSIGNAL_REQUEST_HEADERS"
    }.freeze

    # @!visibility private
    FLOAT_OPTIONS = {
      :cpu_count => "APPSIGNAL_CPU_COUNT"
    }.freeze

    # @!visibility private
    attr_reader :root_path, :env, :config_hash

    # List of config option sources. If a config option was set by a source,
    # it's listed in that source's config options hash.
    #
    # These options are merged as the config is initialized.
    # Their values cannot be changed after the config is initialized.
    #
    # Used by the diagnose report to list which value was read from which source.
    # @!visibility private
    attr_reader :system_config, :loaders_config, :initial_config, :file_config,
      :env_config, :override_config, :dsl_config

    # Initialize a new AppSignal configuration object.
    #
    # @param root_path [String] Path to the root of the application.
    # @param env [String] The environment to load when AppSignal is started. It
    #   will look for an environment with this name in the `config/appsignal.yml`
    #   config file.
    # @param load_yaml_file [Boolean] Whether to load configuration from
    #   the YAML config file. Defaults to true.
    # @return [Config] The initialized configuration object.
    # @!visibility private
    # @see https://docs.appsignal.com/ruby/configuration/
    #   Configuration documentation
    # @see https://docs.appsignal.com/ruby/configuration/load-order.html
    #   Configuration load order
    # @see https://docs.appsignal.com/ruby/instrumentation/integrating-appsignal.html
    #   How to integrate AppSignal manually
    def initialize(
      root_path,
      env,
      load_yaml_file: true
    )
      @load_yaml_file = load_yaml_file
      @root_path = root_path.to_s
      @yml_config_file_error = false
      @yml_config_file = yml_config_file
      @valid = false

      @env = env.to_s
      @config_hash = {}
      @system_config = {}
      @loaders_config = {}
      @initial_config = {}
      @file_config = {}
      @env_config = {}
      @override_config = {}
      @dsl_config = {} # Can be set using `Appsignal.configure`

      load_config
    end

    # @!visibility private
    def load_config
      # Set defaults
      # Deep duplicate each frozen default value
      merge(DEFAULT_CONFIG.transform_values(&:dup))

      # Set config based on the system
      @system_config = detect_from_system
      merge(system_config)

      # Set defaults from loaders in reverse order so the first registered
      # loader's defaults overwrite all others
      self.class.loader_defaults.reverse.each do |loader_defaults|
        options = config_hash
        new_loader_defaults = {}
        defaults = loader_defaults[:options]
        defaults.each do |option, value|
          new_loader_defaults[option] =
            if ARRAY_OPTIONS.key?(option)
              # Merge arrays: new value first
              value + options[option]
            else
              value
            end
        end
        @loaders_config.merge!(new_loader_defaults.merge(
          :root_path => loader_defaults[:root_path],
          :env => loader_defaults[:env]
        ))
        merge(new_loader_defaults)
      end

      # Track origin of env
      @initial_config[:env] = @env

      # Load the config file if it exists
      if @load_yaml_file
        @file_config = load_from_disk || {}
        merge(file_config)
      elsif yml_config_file?
        # When in a `config/appsignal.rb` file and it detects a
        # `config/appsignal.yml` file.
        # Only logged and printed on `Appsignal.start`.
        message = "Both a Ruby and YAML configuration file are found. " \
          "The `config/appsignal.yml` file is ignored when the " \
          "config is loaded from `config/appsignal.rb`. Move all config to " \
          "the `config/appsignal.rb` file and remove the " \
          "`config/appsignal.yml` file."
        Appsignal::Utils::StdoutAndLoggerMessage.warning(message)
      end

      # Load config from environment variables
      @env_config = load_from_environment
      merge(env_config)
      # Track origin of env
      env_loaded_from_env = ENV.fetch("APPSIGNAL_APP_ENV", nil)
      @env_config[:env] = env_loaded_from_env if env_loaded_from_env
    end

    # @return [String] System's tmp directory.
    # @!visibility private
    def self.system_tmp_dir
      if Gem.win_platform?
        Dir.tmpdir
      else
        File.realpath("/tmp")
      end
    end

    # Fetch a configuration value by key.
    #
    # @param key [Symbol, String] The configuration option key to fetch.
    # @return [Object] The configuration value.
    # @!visibility private
    def [](key)
      config_hash[key]
    end

    # Update the internal config hash.
    #
    # This method does not update the config in the extension and agent. It
    # should not be used to update the config after AppSignal has started.
    #
    # @param key [Symbol, String] The configuration option key to set.
    # @param value [Object] The configuration value to set.
    # @return [void]
    # @!visibility private
    def []=(key, value)
      config_hash[key] = value
    end

    # @!visibility private
    def log_level
      option = config_hash[:log_level]
      level =
        if option
          log_level_option = LOG_LEVEL_MAP[option]
          log_level_option
        end
      level.nil? ? Appsignal::Config::DEFAULT_LOG_LEVEL : level
    end

    # @!visibility private
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

    # Check if the configuration is valid.
    #
    # @return [Boolean] True if the configuration is valid, false otherwise.
    def valid?
      @valid
    end

    # Check if AppSignal is active for the current environment.
    #
    # @return [Boolean] True if active for the current environment.
    def active_for_env?
      config_hash[:active]
    end

    # Check if AppSignal is active.
    #
    # @return [Boolean] True if valid and active for the current environment.
    def active?
      valid? && active_for_env?
    end

    # @!visibility private
    def write_to_environment # rubocop:disable Metrics/AbcSize
      ENV["_APPSIGNAL_ACTIVE"]                       = active?.to_s
      ENV["_APPSIGNAL_AGENT_PATH"]                   = File.expand_path("../../ext", __dir__).to_s
      ENV["_APPSIGNAL_APP_NAME"]                     = config_hash[:name]
      ENV["_APPSIGNAL_APP_PATH"]                     = root_path.to_s
      ENV["_APPSIGNAL_BIND_ADDRESS"]                 = config_hash[:bind_address].to_s
      ENV["_APPSIGNAL_CA_FILE_PATH"]                 = config_hash[:ca_file_path].to_s
      ENV["_APPSIGNAL_CPU_COUNT"]                    = config_hash[:cpu_count].to_s
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
      ENV["_APPSIGNAL_NGINX_PORT"]                   = config_hash[:nginx_port].to_s
      if config_hash[:working_directory_path]
        ENV["_APPSIGNAL_WORKING_DIRECTORY_PATH"] = config_hash[:working_directory_path]
      end
      ENV["_APP_REVISION"] = config_hash[:revision].to_s
    end

    # @!visibility private
    def merge_dsl_options(options)
      @dsl_config.merge!(options)
      merge(options)
    end

    # Apply any overrides for invalid settings.
    # @!visibility private
    def apply_overrides
      @override_config = determine_overrides
      merge(override_config)
    end

    # @return [void]
    # @!visibility private
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
        logger.error "Push API key not set after loading config"
      else
        @valid = true
      end
    end

    # Deep freeze the config object so it cannot be modified during the runtime
    # of the Ruby app.
    #
    # @return [void]
    # @!visibility private
    # @since 4.0.0
    def freeze
      super
      config_hash.freeze
      config_hash.transform_values(&:freeze)
    end

    # @api private
    def yml_config_file?
      return false unless yml_config_file

      File.exist?(yml_config_file)
    end

    private

    def logger
      Appsignal.internal_logger
    end

    def yml_config_file
      @yml_config_file ||=
        root_path.nil? ? nil : File.join(root_path, "config", "appsignal.yml")
    end

    def detect_from_system
      {}.tap do |hash|
        hash[:log] = "stdout" if Appsignal::System.heroku?

        # Make AppSignal active by default if APPSIGNAL_PUSH_API_KEY
        # environment variable is present and not empty.
        env_push_api_key = ENV["APPSIGNAL_PUSH_API_KEY"] || ""
        hash[:active] = true unless env_push_api_key.strip.empty?

        hash[:enable_at_exit_hook] = "always" if Appsignal::Extension.running_in_container?

        # Set revision from REVISION file if present in project root
        # This helps with Capistrano and Hatchbox.io deployments
        revision_from_file = detect_revision_from_file
        hash[:revision] = revision_from_file if revision_from_file
      end
    end

    def detect_revision_from_file
      return unless root_path

      revision_file_path = File.join(root_path, "REVISION")
      unless File.exist?(revision_file_path)
        logger.debug "No REVISION file found at: #{revision_file_path}"
        return
      end

      unless File.readable?(revision_file_path)
        logger.debug "REVISION file is not readable at: #{revision_file_path}"
        return
      end

      begin
        revision_content = File.read(revision_file_path).strip
        if revision_content.empty?
          logger.debug "REVISION file found but is empty at: #{revision_file_path}"
          nil
        else
          logger.debug "REVISION file found and read successfully at: #{revision_file_path}"
          revision_content
        end
      rescue SystemCallError => e
        logger.debug "Error occurred while reading REVISION file at " \
          "#{revision_file_path}: #{e.class}: #{e.message}\n#{e.backtrace}"
        nil
      end
    end

    def load_from_disk
      return unless yml_config_file?

      read_options = YAML::VERSION >= "4.0.0" ? { :aliases => true } : {}
      configurations = YAML.load(ERB.new(File.read(yml_config_file)).result, **read_options)
      config_for_this_env = configurations[env]
      if config_for_this_env
        config_for_this_env.transform_keys(&:to_sym)
      else
        logger.error "Not loading from config file: config for '#{env}' not found"
        nil
      end
    rescue => e
      @yml_config_file_error = true
      message = "An error occurred while loading the AppSignal config file. " \
        "Not starting AppSignal.\n" \
        "File: #{yml_config_file.inspect}\n" \
        "#{e.class.name}: #{e}"
      Kernel.warn "appsignal: #{message}"
      logger.error "#{message}\n#{e.backtrace.join("\n")}"
      nil
    end

    def load_from_environment
      config = {}

      # Configuration with string type
      STRING_OPTIONS.each do |option, env_key|
        env_var = ENV.fetch(env_key, nil)
        next unless env_var

        config[option] = env_var
      end

      # Configuration with boolean type
      BOOLEAN_OPTIONS.each do |option, env_key|
        env_var = ENV.fetch(env_key, nil)
        next unless env_var

        config[option] = env_var.casecmp("true").zero?
      end

      # Configuration with array of strings type
      ARRAY_OPTIONS.each do |option, env_key|
        env_var = ENV.fetch(env_key, nil)
        next unless env_var

        config[option] = env_var.split(",")
      end

      # Configuration with float type
      FLOAT_OPTIONS.each do |option, env_key|
        env_var = ENV.fetch(env_key, nil)
        next unless env_var

        config[option] = env_var.to_f
      end

      config
    end

    # Set config options based on the final user config. Fix any conflicting
    # config.
    def determine_overrides
      config = {}
      # If an error was detected during config file reading/parsing and the new
      # behavior is enabled to not start AppSignal on incomplete config, do not
      # start AppSignal.
      config[:active] = false if @yml_config_file_error

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
        logger.debug("Config key '#{key}' is being overwritten") unless config_hash[key].nil?
        config_hash[key] = value
      end
    end

    # Configuration DSL for use in configuration blocks.
    #
    # This class provides a Domain Specific Language for configuring AppSignal
    # within the `Appsignal.configure` block. It provides getter and setter
    # methods for all configuration options.
    #
    # @example Using the configuration DSL
    #   Appsignal.configure do |config|
    #     config.name = "My App"
    #     config.active = true
    #     config.push_api_key = "your-api-key"
    #     config.ignore_actions = ["StatusController#health"]
    #   end
    #
    # @see AppSignal Ruby gem configuration
    #   https://docs.appsignal.com/ruby/configuration.html
    class ConfigDSL
      # @!visibility private
      # @return [Hash] Hash containing the DSL option values
      attr_reader :dsl_options

      # @!visibility private
      def initialize(config)
        @config = config
        @dsl_options = {}
      end

      # Returns the application's root path.
      #
      # @return [String] The root path of the application
      def app_path
        @config.root_path
      end

      # Returns the current environment name.
      #
      # @return [String] The environment name (e.g., "production", "development")
      def env
        @config.env
      end

      # Returns true if the given environment name matches the loaded
      # environment name.
      #
      # @param given_env [String, Symbol]
      # @return [TrueClass, FalseClass]
      def env?(given_env)
        env == given_env.to_s
      end

      # Activates AppSignal if the current environment matches any of the given environments.
      #
      # @param envs [Array<String, Symbol>] List of environment names to activate for
      # @return [Boolean] true if AppSignal was activated, false otherwise
      #
      # @example Activate for production and staging
      #   config.activate_if_environment(:production, :staging)
      def activate_if_environment(*envs)
        self.active = envs.map(&:to_s).include?(env)
      end

      # @!group String Configuration Options

      # @!attribute [rw] activejob_report_errors
      #   @return [String] Error reporting mode for ActiveJob ("all", "discard" or "none")
      # @!attribute [rw] name
      #   @return [String] The application name
      # @!attribute [rw] bind_address
      #   @return [String] The host to the agent binds to for its HTTP server
      # @!attribute [rw] ca_file_path
      #   @return [String] Path to the CA certificate file
      # @!attribute [rw] hostname
      #   @return [String] Override for the detected hostname
      # @!attribute [rw] host_role
      #   @return [String] Role of the host for grouping in metrics
      # @!attribute [rw] http_proxy
      #   @return [String] HTTP proxy URL
      # @!attribute [rw] log
      #   @return [String] Log destination ("file" or "stdout")
      # @!attribute [rw] log_level
      #   @return [String] AppSignal internal logger
      #     log level ("error", "warn", "info", "debug", "trace")
      # @!attribute [rw] log_path
      #   @return [String] Path to the log directory
      # @!attribute [rw] logging_endpoint
      #   @return [String] Endpoint for log transmission
      # @!attribute [rw] endpoint
      #   @return [String] Push API endpoint URL
      # @!attribute [rw] push_api_key
      #   @return [String] AppSignal Push API key
      # @!attribute [rw] sidekiq_report_errors
      #   @return [String] Error reporting mode for Sidekiq ("all", "discard" or "none")
      # @!attribute [rw] statsd_port
      #   @return [String] Port for StatsD metrics
      # @!attribute [rw] nginx_port
      #   @return [String] Port for Nginx metrics collection
      # @!attribute [rw] working_directory_path
      #   @return [String] Override for the agent working directory
      # @!attribute [rw] revision
      #   @return [String] Application revision identifier

      # @!endgroup
      Appsignal::Config::STRING_OPTIONS.each_key do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, value.to_s)
        end
      end

      # @!group Boolean Configuration Options

      # @!attribute [rw] active
      #   @return [Boolean] Activate AppSignal for the loaded environment
      # @!attribute [rw] enable_allocation_tracking
      #   @return [Boolean] Configure whether allocation tracking is enabled
      # @!attribute [rw] enable_at_exit_reporter
      #   @return [Boolean] Configure whether the at_exit reporter is enabled
      # @!attribute [rw] enable_host_metrics
      #   @return [Boolean] Configure whether host metrics collection is enabled
      # @!attribute [rw] enable_minutely_probes
      #   @return [Boolean] Configure whether minutely probes are enabled
      # @!attribute [rw] enable_statsd
      #   @return [Boolean] Configure whether the StatsD metrics endpoint on the agent is enabled
      # @!attribute [rw] enable_nginx_metrics
      #   @return [Boolean] Configure whether the agent's NGINX metrics endpoint is enabled
      # @!attribute [rw] enable_gvl_global_timer
      #   @return [Boolean] Configure whether the GVL global timer instrumentationis enabled
      # @!attribute [rw] enable_gvl_waiting_threads
      #   @return [Boolean] Configure whether GVL waiting threads instrumentation is enabled
      # @!attribute [rw] enable_rails_error_reporter
      #   @return [Boolean] Configure whether Rails error reporter integration is enabled
      # @!attribute [rw] enable_active_support_event_log_reporter
      #   @return [Boolean] Configure whether ActiveSupport::EventReporter integration is enabled
      # @!attribute [rw] enable_rake_performance_instrumentation
      #   @return [Boolean] Configure whether Rake performance instrumentation is enabled
      # @!attribute [rw] files_world_accessible
      #   @return [Boolean] Configure whether files created by AppSignal should be world accessible
      # @!attribute [rw] instrument_http_rb
      #   @return [Boolean] Configure whether to instrument requests made with the http.rb gem
      # @!attribute [rw] instrument_net_http
      #   @return [Boolean] Configure whether to instrument requests made with Net::HTTP
      # @!attribute [rw] instrument_ownership
      #   @return [Boolean] Configure whether to instrument the Ownership gem
      # @!attribute [rw] instrument_redis
      #   @return [Boolean] Configure whether to instrument Redis queries
      # @!attribute [rw] instrument_sequel
      #   @return [Boolean] Configure whether to instrument Sequel queries
      # @!attribute [rw] ownership_set_namespace
      #   @return [Boolean] Configure whether the Ownership gem instrumentation should set namespace
      # @!attribute [rw] running_in_container
      #   @return [Boolean] Configure whether the application is running in a container
      # @!attribute [rw] send_environment_metadata
      #   @return [Boolean] Configure whether to send environment metadata
      # @!attribute [rw] send_params
      #   @return [Boolean] Configure whether to send request parameters
      # @!attribute [rw] send_session_data
      #   @return [Boolean] Configure whether to send request session data

      # @!endgroup
      Appsignal::Config::BOOLEAN_OPTIONS.each_key do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, !!value)
        end
      end

      # @!group Array Configuration Options

      # @!attribute [rw] dns_servers
      #   @return [Array<String>] Custom DNS servers to use
      # @!attribute [rw] filter_metadata
      #   @return [Array<String>] Metadata keys to filter from trace data
      # @!attribute [rw] filter_parameters
      #   @return [Array<String>] Keys of parameter to filter
      # @!attribute [rw] filter_session_data
      #   @return [Array<String>] Request session data keys to filter
      # @!attribute [rw] ignore_actions
      #   @return [Array<String>] Ignore traces by action names
      # @!attribute [rw] ignore_errors
      #   @return [Array<String>] List of errors to not report
      # @!attribute [rw] ignore_logs
      #   @return [Array<String>] Ignore log messages by substrings
      # @!attribute [rw] ignore_namespaces
      #   @return [Array<String>] Ignore traces by namespaces
      # @!attribute [rw] request_headers
      #   @return [Array<String>] HTTP request headers to include in error reports

      # @!endgroup
      Appsignal::Config::ARRAY_OPTIONS.each_key do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, value.to_a)
        end
      end

      # @!group Float Configuration Options

      # @!attribute [rw] cpu_count
      #   @return [Float] CPU count override for metrics collection

      # @!endgroup
      Appsignal::Config::FLOAT_OPTIONS.each_key do |option|
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
