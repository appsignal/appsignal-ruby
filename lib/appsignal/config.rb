# frozen_string_literal: true

require "erb"
require "yaml"
require "uri"
require "socket"
require "tmpdir"

module Appsignal
  class Config
    # @api private
    def self.loader_defaults
      @loader_defaults ||= []
    end

    # @api private
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
    # @api private
    def self.determine_env(initial_env = nil)
      [
        initial_env,
        ENV.fetch("_APPSIGNAL_CONFIG_FILE_ENV", nil), # PRIVATE ENV var used by the diagnose CLI
        ENV.fetch("APPSIGNAL_APP_ENV", nil),
        ENV.fetch("RAILS_ENV", nil),
        ENV.fetch("RACK_ENV", nil)
      ].compact.each do |env|
        return env if env
      end

      loader_defaults.reverse.each do |loader_defaults|
        env = loader_defaults[:env]
        return env if env
      end

      nil
    end

    # Determine which root path AppSignal should initialize with.
    # @api private
    def self.determine_root_path
      app_path_env_var = ENV.fetch("APPSIGNAL_APP_PATH", nil)
      return app_path_env_var if app_path_env_var

      loader_defaults.reverse.each do |loader_defaults|
        root_path = loader_defaults[:root_path]
        return root_path if root_path
      end

      Dir.pwd
    end

    # @api private
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

    # @api private
    DEFAULT_CONFIG = {
      :activejob_report_errors => "all",
      :ca_file_path => File.expand_path(File.join("../../../resources/cacert.pem"), __FILE__),
      :dns_servers => [],
      :enable_allocation_tracking => true,
      :enable_at_exit_reporter => true,
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
    STRING_OPTIONS = {
      :activejob_report_errors => "APPSIGNAL_ACTIVEJOB_REPORT_ERRORS",
      :name => "APPSIGNAL_APP_NAME",
      :bind_address => "APPSIGNAL_BIND_ADDRESS",
      :ca_file_path => "APPSIGNAL_CA_FILE_PATH",
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
      :working_directory_path => "APPSIGNAL_WORKING_DIRECTORY_PATH",
      :revision => "APP_REVISION"
    }.freeze

    # @api private
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
      :enable_rake_performance_instrumentation =>
        "APPSIGNAL_ENABLE_RAKE_PERFORMANCE_INSTRUMENTATION",
      :files_world_accessible => "APPSIGNAL_FILES_WORLD_ACCESSIBLE",
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

    # @api private
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

    # @api private
    FLOAT_OPTIONS = {
      :cpu_count => "APPSIGNAL_CPU_COUNT"
    }.freeze

    # @api private
    attr_reader :root_path, :env, :config_hash

    # List of config option sources. If a config option was set by a source,
    # it's listed in that source's config options hash.
    #
    # These options are merged as the config is initialized.
    # Their values cannot be changed after the config is initialized.
    #
    # Used by the diagnose report to list which value was read from which source.
    # @api private
    attr_reader :system_config, :loaders_config, :initial_config, :file_config,
      :env_config, :override_config, :dsl_config

    # Initialize a new configuration object for AppSignal.
    #
    # @param root_path [String] Root path of the app.
    # @param env [String] The environment to load when AppSignal is started. It
    #   will look for an environment with this name in the `config/appsignal.yml`
    #   config file.
    #
    # @api private
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
      @config_file_error = false
      @config_file = config_file
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

    # @api private
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
      option = config_hash[:log_level]
      level =
        if option
          log_level_option = LOG_LEVEL_MAP[option]
          log_level_option
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
      if config_hash[:working_directory_path]
        ENV["_APPSIGNAL_WORKING_DIRECTORY_PATH"] = config_hash[:working_directory_path]
      end
      ENV["_APP_REVISION"] = config_hash[:revision].to_s
    end

    # @api private
    def merge_dsl_options(options)
      @dsl_config.merge!(options)
      merge(options)
    end

    # @api private
    def validate
      # Apply any overrides for invalid settings.
      @override_config = determine_overrides
      merge(override_config)

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
    # @api private
    # @since 4.0.0
    def freeze
      super
      config_hash.freeze
      config_hash.transform_values(&:freeze)
    end

    # @api private
    def yml_config_file?
      return false unless config_file

      File.exist?(config_file)
    end

    private

    def logger
      Appsignal.internal_logger
    end

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
      return unless yml_config_file?

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
      @config_file_error = true
      message = "An error occurred while loading the AppSignal config file. " \
        "Not starting AppSignal.\n" \
        "File: #{config_file.inspect}\n" \
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
      config[:active] = false if @config_file_error

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

      def activate_if_environment(*envs)
        self.active = envs.map(&:to_s).include?(env)
      end

      Appsignal::Config::STRING_OPTIONS.each_key do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, value.to_s)
        end
      end

      Appsignal::Config::BOOLEAN_OPTIONS.each_key do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, !!value)
        end
      end

      Appsignal::Config::ARRAY_OPTIONS.each_key do |option|
        define_method(option) do
          fetch_option(option)
        end

        define_method("#{option}=") do |value|
          update_option(option, value.to_a)
        end
      end

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
