describe Appsignal::Config do
  describe "#initialize" do
    describe "environment" do
      context "when environment is nil" do
        let(:config) { described_class.new("", nil) }

        it "sets an empty string" do
          expect(config.env).to eq("")
        end
      end

      context "when environment is given" do
        let(:env) { "my_env" }
        let(:config) { described_class.new("/root/path", "my_env") }

        it "sets the environment" do
          expect(config.env).to eq(env)
        end

        it "sets the environment as loaded through the initial_config" do
          expect(config.initial_config).to eq(:env => env)
          expect(config.config_hash).to_not have_key(:env)
          expect(config.config_hash).to_not have_key(:root_path)
        end

        context "with APPSIGNAL_APP_ENV environment variable" do
          let(:env_env) { "my_env_env" }
          before { ENV["APPSIGNAL_APP_ENV"] = env_env }

          it "uses the environment variable" do
            expect(config.env).to eq(env_env)
          end

          it "sets the environment as loaded through the env_config" do
            expect(config.initial_config).to eq(:env => env)
            expect(config.env_config).to eq(:env => env_env)
            expect(config.config_hash).to_not have_key(:env)
            expect(config.config_hash).to_not have_key(:root_path)
          end
        end
      end
    end
  end

  describe "config based on the system" do
    let(:config) { silence { project_fixture_config(:none) } }

    describe ":active" do
      subject { config[:active] }

      context "with APPSIGNAL_PUSH_API_KEY env variable" do
        context "when not empty" do
          before { ENV["APPSIGNAL_PUSH_API_KEY"] = "abc" }

          it "becomes active" do
            expect(subject).to be_truthy
          end

          it "sets the push_api_key as loaded through the env_config" do
            expect(config.env_config).to include(:push_api_key => "abc")
            expect(config.system_config).to include(:active => true)
          end
        end

        context "when empty string" do
          before { ENV["APPSIGNAL_PUSH_API_KEY"] = "" }

          it "does not becomes active" do
            expect(subject).to be_falsy
          end

          it "sets the push_api_key as loaded through the env_config" do
            expect(config.env_config).to include(:push_api_key => "")
            expect(config.system_config).to_not have_key(:active)
          end
        end

        context "when blank string" do
          before { ENV["APPSIGNAL_PUSH_API_KEY"] = " " }

          it "does not becomes active" do
            expect(subject).to be_falsy
          end

          it "sets the push_api_key as loaded through the env_config" do
            expect(config.env_config).to include(:push_api_key => " ")
            expect(config.system_config).to_not have_key(:active)
          end
        end
      end

      context "without APPSIGNAL_PUSH_API_KEY env variable" do
        it "remains inactive" do
          expect(subject).to be_falsy
        end
      end
    end

    describe ":log" do
      subject { config[:log] }

      context "when running on Heroku" do
        around { |example| recognize_as_heroku { example.run } }

        it "is set to stdout" do
          expect(subject).to eq("stdout")
        end

        it "sets the log as loaded through the system" do
          expect(config.system_config).to include(:log => "stdout")
        end
      end

      context "when not running on Heroku" do
        it "is set to file" do
          expect(subject).to eq("file")
        end

        it "does not set log as loaded through the system" do
          expect(config.system_config).to_not have_key(:log)
        end
      end
    end
  end

  describe "loader default config" do
    let(:config) do
      described_class.new("some-path", "production")
    end
    before do
      class TestLoader < Appsignal::Loaders::Loader
        register :test
        def on_load
          register_config_defaults(
            :env => "new_env",
            :root_path => "/some/path",
            :my_option => "my_value",
            :nil_option => nil
          )
        end
      end
      load_loader(:test)
    end
    after do
      Object.send(:remove_const, :TestLoader)
      unregister_loader(:first)
    end

    it "merges with the loader defaults" do
      expect(config.config_hash).to include(:my_option => "my_value")
    end

    it "does not set any nil values" do
      expect(config.config_hash).to_not have_key(:nil_option)
    end

    it "overwrites the env" do
      expect(config.env).to eq("new_env")
    end

    it "overwrites the path" do
      expect(config.root_path).to eq("/some/path")
    end

    context "with multiple loaders" do
      before do
        class SecondLoader < Appsignal::Loaders::Loader
          register :second
          def on_load
            register_config_defaults(
              :env => "second_env",
              :root_path => "/second/path",
              :my_option => "second_value",
              :second_option => "second_value"
            )
          end
        end
        load_loader(:second)
      end
      after do
        Object.send(:remove_const, :SecondLoader)
        unregister_loader(:second)
      end

      it "makes the first loader's config leading" do
        expect(config.config_hash).to include(
          :my_option => "my_value",
          :second_option => "second_value"
        )
        expect(config.env).to eq("new_env")
        expect(config.root_path).to eq("/some/path")
      end
    end
  end

  describe "initial config" do
    let(:initial_config) do
      {
        :push_api_key => "abc",
        :name => "TestApp",
        :active => true,
        :revision => "v2.5.1",
        :request_headers => []
      }
    end
    let(:config) do
      described_class.new("non-existing-path", "production", initial_config)
    end

    it "merges with the default config" do
      expect(config.config_hash).to eq(
        :active                         => true,
        :activejob_report_errors        => "all",
        :ca_file_path                   => File.join(resources_dir, "cacert.pem"),
        :dns_servers                    => [],
        :enable_allocation_tracking     => true,
        :enable_gvl_global_timer        => true,
        :enable_gvl_waiting_threads     => true,
        :enable_host_metrics            => true,
        :enable_minutely_probes         => true,
        :enable_statsd                  => true,
        :enable_nginx_metrics           => false,
        :enable_rails_error_reporter    => true,
        :enable_rake_performance_instrumentation => false,
        :endpoint                       => "https://push.appsignal.com",
        :files_world_accessible         => true,
        :filter_metadata                => [],
        :filter_parameters              => [],
        :filter_session_data            => [],
        :ignore_actions                 => [],
        :ignore_errors                  => [],
        :ignore_logs                    => [],
        :ignore_namespaces              => [],
        :instrument_http_rb             => true,
        :instrument_net_http            => true,
        :instrument_redis               => true,
        :instrument_sequel              => true,
        :log                            => "file",
        :logging_endpoint               => "https://appsignal-endpoint.net",
        :name                           => "TestApp",
        :push_api_key                   => "abc",
        :request_headers                => [],
        :revision                       => "v2.5.1",
        :send_environment_metadata      => true,
        :send_params                    => true,
        :send_session_data              => true,
        :sidekiq_report_errors          => "all"
      )
    end

    it "sets the initial_config" do
      expect(config.initial_config).to eq(initial_config)
    end

    describe "overriding system detected config" do
      describe ":running_in_container" do
        let(:config) do
          described_class.new(
            "non-existing-path",
            "production",
            :running_in_container => true
          )
        end
        subject { config[:running_in_container] }

        it "overrides system detected config" do
          expect(subject).to be_truthy
        end
      end

      describe ":active" do
        subject { config[:active] }

        context "with APPSIGNAL_PUSH_API_KEY env variable" do
          let(:config) do
            described_class.new(
              "non-existing-path",
              "production",
              :active => false,
              :request_headers => []
            )
          end
          before { ENV["APPSIGNAL_PUSH_API_KEY"] = "abc" }

          it "sets given config rather than env variable" do
            expect(subject).to be_falsy
          end
        end
      end
    end
  end

  context "when root path is nil" do
    let(:config) { described_class.new(nil, "production") }

    it "is not valid or active" do
      expect(config.valid?).to be_falsy
      expect(config.active?).to be_falsy
    end
  end

  context "without config file" do
    let(:config) { described_class.new(tmp_dir, "production") }

    it "is not valid or active" do
      expect(config.valid?).to be_falsy
      expect(config.active?).to be_falsy
    end
  end

  context "with a config file" do
    let(:config) { project_fixture_config("production") }

    context "with valid config" do
      it "is valid and active" do
        expect(config.valid?).to be_truthy
        expect(config.active?).to be_truthy
      end

      it "does not log an error" do
        log = capture_logs { config }
        expect(log).to_not contains_log(:error)
      end
    end

    context "with an overridden config file" do
      let(:config) do
        project_fixture_config("production", {}, Appsignal.internal_logger,
          File.join(project_fixture_path, "config", "appsignal.yml"))
      end

      it "is valid and active" do
        expect(config.valid?).to be_truthy
        expect(config.active?).to be_truthy
      end

      context "with an invalid overridden config file" do
        let(:config) do
          project_fixture_config("production", {}, Appsignal.internal_logger,
            File.join(project_fixture_path, "config", "missing.yml"))
        end

        it "is not valid" do
          expect(config.valid?).to be_falsy
        end
      end
    end

    context "with the config file causing an error" do
      let(:config_path) do
        File.expand_path(
          File.join(File.dirname(__FILE__), "../../support/fixtures/projects/broken")
        )
      end
      let(:config) { Appsignal::Config.new(config_path, "foo") }

      context "when APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR is not set" do
        it "logs & prints an error, skipping the file source" do
          stdout = std_stream
          stderr = std_stream
          log = capture_logs { capture_std_streams(stdout, stderr) { config } }
          message = "An error occurred while loading the AppSignal config file. " \
            "Skipping file config. " \
            "In future versions AppSignal will not start on a config file " \
            "error. To opt-in to this new behavior set " \
            "'APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR=1' in your system " \
            "environment.\n" \
            "File: #{File.join(config_path, "config", "appsignal.yml").inspect}\n" \
            "KeyError: key not found"
          expect(log).to contains_log :error, message
          expect(log).to include("/appsignal/config.rb:") # Backtrace
          expect(stdout.read).to_not include("appsignal:")
          expect(stderr.read).to include "appsignal: #{message}"
          expect(config.file_config).to eql({})
        end
      end

      context "when APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR=1 is set" do
        it "does not start AppSignal, logs & prints an error" do
          stdout = std_stream
          stderr = std_stream
          ENV["APPSIGNAL_ACTIVE"] = "true"
          ENV["APPSIGNAL_APP_NAME"] = "My app"
          ENV["APPSIGNAL_APP_ENV"] = "dev"
          ENV["APPSIGNAL_PUSH_API_KEY"] = "something valid"
          ENV["APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR"] = "1"
          log = capture_logs { capture_std_streams(stdout, stderr) { config } }
          message = "An error occurred while loading the AppSignal config file. " \
            "Not starting AppSignal because APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR is set.\n" \
            "File: #{File.join(config_path, "config", "appsignal.yml").inspect}\n" \
            "KeyError: key not found"
          expect(log).to contains_log :error, message
          expect(log).to include("/appsignal/config.rb:") # Backtrace
          expect(stdout.read).to_not include("appsignal:")
          expect(stderr.read).to include "appsignal: #{message}"
          expect(config.file_config).to eql({})
          expect(config.active?).to be(false)
        end
      end
    end

    it "sets the file_config" do
      # config found in spec/support/project_fixture/config/appsignal.yml
      expect(config.file_config).to match(
        :active => true,
        :push_api_key => "abc",
        :name => "TestApp",
        :request_headers => kind_of(Array),
        :enable_minutely_probes => false
      )
    end

    describe "overriding system and defaults config" do
      let(:config) do
        described_class.new(
          "non-existing-path",
          "production",
          :running_in_container => true,
          :debug => true,
          :log_level => "debug"
        )
      end

      it "overrides system detected and defaults config" do
        expect(config[:running_in_container]).to be_truthy
        expect(config[:debug]).to be_truthy
        expect(config[:log_level]).to eq("debug")
      end
    end

    context "with the env name as a symbol" do
      let(:config) { project_fixture_config(:production) }

      it "loads the config" do
        expect(config.valid?).to be_truthy
        expect(config.active?).to be_truthy

        expect(config[:push_api_key]).to eq("abc")
      end
    end

    context "without the selected env" do
      let(:config) { project_fixture_config("nonsense") }
      let(:log_stream) { std_stream }
      let(:log) { log_contents(log_stream) }

      it "is not valid or active" do
        expect(config.valid?).to be_falsy
        expect(config.active?).to be_falsy
      end

      it "logs an error" do
        use_logger_with(log_stream) { config }
        expect(log)
          .to contains_log(:error, "Not loading from config file: config for 'nonsense' not found")
        expect(log)
          .to contains_log(:error, "Push API key not set after loading config")
      end
    end
  end

  context "with config in the environment" do
    let(:config) do
      described_class.new(
        "non-existing-path",
        "production",
        :running_in_container => true,
        :debug => true
      )
    end
    let(:working_directory_path) { File.join(tmp_dir, "test_working_directory_path") }
    let(:env_config) do
      {
        :active => true,
        :activejob_report_errors => "all",
        :bind_address => "0.0.0.0",
        :ca_file_path => "/some/path",
        :cpu_count => 1.5,
        :dns_servers => ["8.8.8.8", "8.8.4.4"],
        :enable_allocation_tracking => false,
        :enable_gvl_global_timer => false,
        :enable_gvl_waiting_threads => false,
        :enable_host_metrics => false,
        :enable_minutely_probes => false,
        :enable_nginx_metrics => false,
        :enable_rails_error_reporter => false,
        :enable_rake_performance_instrumentation => false,
        :enable_statsd => false,
        :endpoint => "https://test.appsignal.com",
        :files_world_accessible => false,
        :filter_metadata => ["key1", "key2"],
        :filter_parameters => ["param1", "param2"],
        :filter_session_data => ["session1", "session2"],
        :host_role => "my host role",
        :hostname => "my hostname",
        :http_proxy => "some proxy",
        :ignore_actions => ["action1", "action2"],
        :ignore_errors => ["ExampleStandardError", "AnotherError"],
        :ignore_logs => ["^start$", "^Completed 2.* in .*ms (.*)"],
        :ignore_namespaces => ["admin", "private_namespace"],
        :instrument_http_rb => false,
        :instrument_net_http => false,
        :instrument_redis => false,
        :instrument_sequel => false,
        :log => "file",
        :log_level => "debug",
        :log_path => "/tmp/something",
        :logging_endpoint => "https://appsignal-endpoint.net/test",
        :name => "App name",
        :push_api_key => "aaa-bbb-ccc",
        :request_headers => ["accept", "accept-charset"],
        :revision => "v2.5.1",
        :running_in_container => true,
        :send_environment_metadata => false,
        :send_params => false,
        :send_session_data => false,
        :sidekiq_report_errors => "all",
        :statsd_port => "7890",
        :working_directory_path => working_directory_path
      }
    end
    let(:env_vars) do
      {
        # Strings
        "APPSIGNAL_ACTIVEJOB_REPORT_ERRORS" => "all",
        "APPSIGNAL_APP_NAME" => "App name",
        "APPSIGNAL_BIND_ADDRESS" => "0.0.0.0",
        "APPSIGNAL_CA_FILE_PATH" => "/some/path",
        "APPSIGNAL_HOSTNAME" => "my hostname",
        "APPSIGNAL_HOST_ROLE" => "my host role",
        "APPSIGNAL_HTTP_PROXY" => "some proxy",
        "APPSIGNAL_LOG" => "file",
        "APPSIGNAL_LOGGING_ENDPOINT" => "https://appsignal-endpoint.net/test",
        "APPSIGNAL_LOG_LEVEL" => "debug",
        "APPSIGNAL_LOG_PATH" => "/tmp/something",
        "APPSIGNAL_PUSH_API_ENDPOINT" => "https://test.appsignal.com",
        "APPSIGNAL_PUSH_API_KEY" => "aaa-bbb-ccc",
        "APPSIGNAL_SIDEKIQ_REPORT_ERRORS" => "all",
        "APPSIGNAL_STATSD_PORT" => "7890",
        "APPSIGNAL_WORKING_DIRECTORY_PATH" => working_directory_path,
        "APP_REVISION" => "v2.5.1",

        # Booleans
        "APPSIGNAL_ACTIVE" => "true",
        "APPSIGNAL_ENABLE_ALLOCATION_TRACKING" => "false",
        "APPSIGNAL_ENABLE_GVL_GLOBAL_TIMER" => "false",
        "APPSIGNAL_ENABLE_GVL_WAITING_THREADS" => "false",
        "APPSIGNAL_ENABLE_HOST_METRICS" => "false",
        "APPSIGNAL_ENABLE_MINUTELY_PROBES" => "false",
        "APPSIGNAL_ENABLE_NGINX_METRICS" => "false",
        "APPSIGNAL_ENABLE_RAILS_ERROR_REPORTER" => "false",
        "APPSIGNAL_ENABLE_RAKE_PERFORMANCE_INSTRUMENTATION" => "false",
        "APPSIGNAL_ENABLE_STATSD" => "false",
        "APPSIGNAL_FILES_WORLD_ACCESSIBLE" => "false",
        "APPSIGNAL_INSTRUMENT_HTTP_RB" => "false",
        "APPSIGNAL_INSTRUMENT_NET_HTTP" => "false",
        "APPSIGNAL_INSTRUMENT_REDIS" => "false",
        "APPSIGNAL_INSTRUMENT_SEQUEL" => "false",
        "APPSIGNAL_RUNNING_IN_CONTAINER" => "true",
        "APPSIGNAL_SEND_ENVIRONMENT_METADATA" => "false",
        "APPSIGNAL_SEND_PARAMS" => "false",
        "APPSIGNAL_SEND_SESSION_DATA" => "false",

        # Arrays
        "APPSIGNAL_DNS_SERVERS" => "8.8.8.8,8.8.4.4",
        "APPSIGNAL_FILTER_METADATA" => "key1,key2",
        "APPSIGNAL_FILTER_PARAMETERS" => "param1,param2",
        "APPSIGNAL_FILTER_SESSION_DATA" => "session1,session2",
        "APPSIGNAL_IGNORE_ACTIONS" => "action1,action2",
        "APPSIGNAL_IGNORE_ERRORS" => "ExampleStandardError,AnotherError",
        "APPSIGNAL_IGNORE_LOGS" => "^start$,^Completed 2.* in .*ms (.*)",
        "APPSIGNAL_IGNORE_NAMESPACES" => "admin,private_namespace",
        "APPSIGNAL_REQUEST_HEADERS" => "accept,accept-charset",

        # Floats
        "APPSIGNAL_CPU_COUNT" => "1.5"
      }
    end
    before do
      env_vars.each do |key, value|
        ENV[key] = value
      end
    end

    it "reads all string env keys" do
      config

      Appsignal::Config::ENV_STRING_KEYS.each do |env_key, option|
        ENV.fetch(env_key) { raise "Config env var '#{env_key}' is not set for this test" }
        expect(config[option]).to eq(ENV.fetch(env_key, nil))
      end
    end

    it "reads all boolean env keys" do
      config

      Appsignal::Config::ENV_BOOLEAN_KEYS.each do |env_key, option|
        ENV.fetch(env_key) { raise "Config env var '#{env_key}' is not set for this test" }
        expect(config[option]).to eq(ENV.fetch(env_key, nil) == "true")
      end
    end

    it "reads all array env keys" do
      config

      Appsignal::Config::ENV_ARRAY_KEYS.each do |env_key, option|
        ENV.fetch(env_key) { raise "Config env var '#{env_key}' is not set for this test" }
        expect(config[option]).to eq(ENV.fetch(env_key, nil).split(","))
      end
    end

    it "reads all float env keys" do
      config

      Appsignal::Config::ENV_FLOAT_KEYS.each do |env_key, option|
        ENV.fetch(env_key) { raise "Config env var '#{env_key}' is not set for this test" }
        expect(config[option]).to eq(ENV.fetch(env_key, nil).to_f)
      end
    end

    it "overrides config with environment values" do
      expect(config.valid?).to be_truthy
      expect(config.active?).to be_truthy
      expect(config.config_hash).to include(env_config)
    end

    context "with mixed case `true` env variables values" do
      before do
        ENV["APPSIGNAL_DEBUG"] = "TRUE"
        ENV["APPSIGNAL_INSTRUMENT_SEQUEL"] = "True"
      end

      it "accepts mixed case `true` values" do
        expect(config[:debug]).to eq(true)
        expect(config[:instrument_sequel]).to eq(true)
      end
    end

    it "sets the env_config" do
      expect(config.env_config).to eq(env_config)
    end
  end

  describe "with config based on overrides" do
    let(:log_stream) { StringIO.new }
    let(:logger) { test_logger(log_stream) }
    let(:logs) { log_contents(log_stream) }
    let(:config) do
      described_class.new(Dir.pwd, "production", config_options, logger)
    end

    if DependencyHelper.rails_present?
      require "active_job"

      context "activejob_report_errors" do
        let(:config_options) { { :activejob_report_errors => "discard" } }

        if DependencyHelper.rails_version >= Gem::Version.new("7.1.0")
          context "when Active Job >= 7.1 and 'discard'" do
            it "does not override the activejob_report_errors value" do
              expect(config[:activejob_report_errors]).to eq("discard")
              expect(config.override_config[:activejob_report_errors]).to be_nil
            end
          end
        else
          context "when Active Job < 7.1 and 'discard'" do
            it "sets activejob_report_errors to 'all'" do
              expect(config[:activejob_report_errors]).to eq("all")
              expect(config.override_config[:activejob_report_errors]).to eq("all")
            end
          end
        end
      end
    end

    context "sidekiq_report_errors" do
      let(:config_options) { { :sidekiq_report_errors => "discard" } }
      before do
        if Appsignal::Hooks::SidekiqHook.instance_variable_defined?(:@version_5_1_or_higher)
          Appsignal::Hooks::SidekiqHook.remove_instance_variable(:@version_5_1_or_higher)
        end
      end

      context "when Sidekiq >= 5.1 and 'discard'" do
        before { stub_const("Sidekiq::VERSION", "5.1.0") }

        it "does not override the sidekiq_report_errors value" do
          expect(config[:sidekiq_report_errors]).to eq("discard")
          expect(config.override_config[:sidekiq_report_errors]).to be_nil
        end
      end

      context "when Sidekiq < 5.1 and 'discard'" do
        before { stub_const("Sidekiq::VERSION", "5.0.0") }

        it "sets sidekiq_report_errors to 'all'" do
          expect(config[:sidekiq_report_errors]).to eq("all")
          expect(config.override_config[:sidekiq_report_errors]).to eq("all")
        end
      end
    end
  end

  describe "config keys" do
    describe ":endpoint" do
      subject { config[:endpoint] }

      context "with an pre-0.12-style endpoint" do
        let(:config) do
          project_fixture_config("production", :endpoint => "https://push.appsignal.com/1")
        end

        it "strips off the path" do
          expect(subject).to eq "https://push.appsignal.com"
        end
      end

      context "with a non-standard port" do
        let(:config) { project_fixture_config("production", :endpoint => "http://localhost:4567") }

        it "keeps the port" do
          expect(subject).to eq "http://localhost:4567"
        end
      end
    end

    describe ":logging_endpoint" do
      subject { config[:logging_endpoint] }

      context "with a non-standard port" do
        let(:config) { project_fixture_config("production", :logging_endpoint => "http://localhost:4567") }

        it "keeps the port" do
          expect(subject).to eq "http://localhost:4567"
        end
      end
    end
  end

  describe "#[]" do
    let(:config) { project_fixture_config(:none, :push_api_key => "foo", :request_headers => []) }

    context "with existing key" do
      it "gets the value" do
        expect(config[:push_api_key]).to eq "foo"
      end
    end

    context "without existing key" do
      it "returns nil" do
        expect(config[:nonsense]).to be_nil
      end
    end
  end

  describe "#[]=" do
    let(:config) { project_fixture_config(:none) }

    context "with existing key" do
      it "changes the value" do
        expect(config[:push_api_key]).to be_nil
        config[:push_api_key] = "abcde"
        expect(config[:push_api_key]).to eq "abcde"
      end
    end

    context "with new key" do
      it "sets the value" do
        expect(config[:foo]).to be_nil
        config[:foo] = "bar"
        expect(config[:foo]).to eq "bar"
      end
    end
  end

  describe "#write_to_environment" do
    let(:config) { project_fixture_config(:production) }
    before do
      config[:bind_address] = "0.0.0.0"
      config[:cpu_count] = 1.5
      config[:logging_endpoint] = "http://localhost:123"
      config[:http_proxy] = "http://localhost"
      config[:ignore_actions] = %w[action1 action2]
      config[:ignore_errors] = %w[ExampleStandardError AnotherError]
      config[:ignore_logs] = ["^start$", "^Completed 2.* in .*ms (.*)"]
      config[:ignore_namespaces] = %w[admin private_namespace]
      config[:log] = "stdout"
      config[:log_path] = "/tmp"
      config[:filter_parameters] = %w[password confirm_password]
      config[:filter_session_data] = %w[key1 key2]
      config[:running_in_container] = false
      config[:dns_servers] = ["8.8.8.8", "8.8.4.4"]
      config[:transaction_debug_mode] = true
      config[:send_environment_metadata] = false
      config[:revision] = "v2.5.1"
      config.write_to_environment
    end

    it "writes the current config to environment variables" do
      expect(ENV.fetch("_APPSIGNAL_ACTIVE", nil)).to eq "true"
      expect(ENV.fetch("_APPSIGNAL_APP_PATH", nil))
        .to end_with("spec/support/fixtures/projects/valid")
      expect(ENV.fetch("_APPSIGNAL_AGENT_PATH", nil)).to end_with("/ext")
      expect(ENV.fetch("_APPSIGNAL_BIND_ADDRESS", nil)).to eq("0.0.0.0")
      expect(ENV.fetch("_APPSIGNAL_CPU_COUNT", nil)).to eq("1.5")
      expect(ENV.fetch("_APPSIGNAL_LOG", nil)).to eq "stdout"
      expect(ENV.fetch("_APPSIGNAL_LOG_FILE_PATH", nil)).to end_with("/tmp/appsignal.log")
      expect(ENV.fetch("_APPSIGNAL_LOGGING_ENDPOINT", nil)).to eq "http://localhost:123"
      expect(ENV.fetch("_APPSIGNAL_PUSH_API_ENDPOINT", nil)).to eq "https://push.appsignal.com"
      expect(ENV.fetch("_APPSIGNAL_PUSH_API_KEY", nil)).to eq "abc"
      expect(ENV.fetch("_APPSIGNAL_APP_NAME", nil)).to eq "TestApp"
      expect(ENV.fetch("_APPSIGNAL_APP_ENV", nil)).to eq "production"
      expect(ENV.fetch("_APPSIGNAL_LANGUAGE_INTEGRATION_VERSION", nil))
        .to eq "ruby-#{Appsignal::VERSION}"
      expect(ENV.fetch("_APPSIGNAL_HTTP_PROXY", nil)).to eq "http://localhost"
      expect(ENV.fetch("_APPSIGNAL_IGNORE_ACTIONS", nil)).to eq "action1,action2"
      expect(ENV.fetch("_APPSIGNAL_IGNORE_ERRORS", nil)).to eq "ExampleStandardError,AnotherError"
      expect(ENV.fetch("_APPSIGNAL_IGNORE_LOGS", nil)).to eq "^start$,^Completed 2.* in .*ms (.*)"
      expect(ENV.fetch("_APPSIGNAL_IGNORE_NAMESPACES", nil)).to eq "admin,private_namespace"
      expect(ENV.fetch("_APPSIGNAL_RUNNING_IN_CONTAINER", nil)).to eq "false"
      expect(ENV.fetch("_APPSIGNAL_ENABLE_HOST_METRICS", nil)).to eq "true"
      expect(ENV.fetch("_APPSIGNAL_HOSTNAME", nil)).to eq ""
      expect(ENV.fetch("_APPSIGNAL_HOST_ROLE", nil)).to eq ""
      expect(ENV.fetch("_APPSIGNAL_PROCESS_NAME", nil)).to include "rspec"
      expect(ENV.fetch("_APPSIGNAL_CA_FILE_PATH", nil))
        .to eq File.join(resources_dir, "cacert.pem")
      expect(ENV.fetch("_APPSIGNAL_DNS_SERVERS", nil)).to eq "8.8.8.8,8.8.4.4"
      expect(ENV.fetch("_APPSIGNAL_FILES_WORLD_ACCESSIBLE", nil)).to eq "true"
      expect(ENV.fetch("_APPSIGNAL_SEND_ENVIRONMENT_METADATA", nil)).to eq "false"
      expect(ENV.fetch("_APPSIGNAL_STATSD_PORT", nil)).to eq ""
      expect(ENV.fetch("_APPSIGNAL_FILTER_PARAMETERS", nil)).to eq "password,confirm_password"
      expect(ENV.fetch("_APPSIGNAL_FILTER_SESSION_DATA", nil)).to eq "key1,key2"
      expect(ENV.fetch("_APP_REVISION", nil)).to eq "v2.5.1"
      expect(ENV).to_not have_key("_APPSIGNAL_WORKING_DIRECTORY_PATH")
    end

    context "with :hostname" do
      before do
        config[:hostname] = "Alices-MBP.example.com"
        config.write_to_environment
      end

      it "sets the modified :hostname" do
        expect(ENV.fetch("_APPSIGNAL_HOSTNAME", nil)).to eq "Alices-MBP.example.com"
      end
    end

    context "with :host_role" do
      before do
        config[:host_role] = "host role"
        config.write_to_environment
      end

      it "sets the modified :host_role" do
        expect(ENV.fetch("_APPSIGNAL_HOST_ROLE", nil)).to eq "host role"
      end
    end

    context "with :working_directory_path" do
      before do
        config[:working_directory_path] = "/tmp/appsignal2"
        config.write_to_environment
      end

      it "sets the modified :working_directory_path" do
        expect(ENV.fetch("_APPSIGNAL_WORKING_DIRECTORY_PATH", nil)).to eq "/tmp/appsignal2"
      end
    end

    context "with :statsd_port" do
      before do
        config[:statsd_port] = "1000"
        config.write_to_environment
      end

      it "sets the statsd_port env var" do
        expect(ENV.fetch("_APPSIGNAL_STATSD_PORT", nil)).to eq "1000"
      end
    end
  end

  describe "#log_file_path" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:config) { project_fixture_config("production", :log_path => log_path) }

    def log_file_path
      capture_stdout(out_stream) { config.log_file_path }
    end

    context "when path is writable" do
      let(:log_path) { File.join(tmp_dir, "writable-path") }
      before { FileUtils.mkdir_p(log_path, :mode => 0o755) }
      after { FileUtils.rm_rf(log_path) }

      it "returns log file path" do
        expect(log_file_path).to eq File.join(log_path, "appsignal.log")
      end

      it "prints no warning" do
        log_file_path
        expect(output).to be_empty
      end
    end

    shared_examples "#log_file_path: tmp path" do
      let(:system_tmp_dir) { described_class.system_tmp_dir }
      before { FileUtils.mkdir_p(system_tmp_dir) }
      after { FileUtils.rm_rf(system_tmp_dir) }

      context "when the /tmp fallback path is writable" do
        before { FileUtils.chmod(0o777, system_tmp_dir) }

        it "returns returns the tmp location" do
          expect(log_file_path).to eq(File.join(system_tmp_dir, "appsignal.log"))
        end

        it "prints a warning" do
          log_file_path
          expect(output).to include "appsignal: Unable to log to '#{log_path}'. " \
            "Logging to '#{system_tmp_dir}' instead."
        end

        it "prints a warning once" do
          capture_stdout(out_stream) do
            log_file_path
            log_file_path
          end
          message = "appsignal: Unable to log to '#{log_path}'. " \
            "Logging to '#{system_tmp_dir}' instead."
          expect(output.scan(message).count).to eq(1)
        end
      end

      context "when the /tmp fallback path is not writable" do
        before { FileUtils.chmod(0o555, system_tmp_dir) }

        it "returns nil" do
          expect(log_file_path).to be_nil
        end

        it "prints a warning" do
          log_file_path
          expect(output).to include "appsignal: Unable to log to '#{log_path}' " \
            "or the '#{system_tmp_dir}' fallback."
        end

        it "prints a warning once" do
          capture_stdout(out_stream) do
            log_file_path
            log_file_path
          end
          message = "appsignal: Unable to log to '#{log_path}' or the '#{system_tmp_dir}' fallback."
          expect(output.scan(message).count).to eq(1)
        end
      end
    end

    context "when path is nil" do
      let(:log_path) { nil }

      context "when root_path is nil" do
        before { allow(config).to receive(:root_path).and_return(nil) }

        include_examples "#log_file_path: tmp path"
      end

      context "when root_path is set" do
        it "returns returns the project log location" do
          expect(log_file_path).to eq File.join(config.root_path, "log/appsignal.log")
        end

        it "prints no warning" do
          log_file_path
          expect(output).to be_empty
        end
      end
    end

    context "when path does not exist" do
      let(:log_path) { "/non-existing" }

      include_examples "#log_file_path: tmp path"
    end

    context "when path is not writable" do
      let(:log_path) { File.join(tmp_dir, "not-writable-path") }
      before { FileUtils.mkdir_p(log_path, :mode => 0o555) }
      after { FileUtils.rm_rf(log_path) }

      include_examples "#log_file_path: tmp path"
    end

    context "when path is a symlink" do
      context "when linked path does not exist" do
        let(:real_path) { File.join(tmp_dir, "real-path") }
        let(:log_path) { File.join(tmp_dir, "symlink-path") }
        before { File.symlink(real_path, log_path) }
        after { FileUtils.rm(log_path) }

        include_examples "#log_file_path: tmp path"
      end

      context "when linked path exists" do
        context "when linked path is not writable" do
          let(:real_path) { File.join(tmp_dir, "real-path") }
          let(:log_path) { File.join(tmp_dir, "symlink-path") }
          before do
            FileUtils.mkdir_p(real_path)
            FileUtils.chmod(0o444, real_path)
            File.symlink(real_path, log_path)
          end
          after do
            FileUtils.rm_rf(real_path)
            FileUtils.rm(log_path)
          end

          include_examples "#log_file_path: tmp path"
        end

        context "when linked path is writable" do
          let(:real_path) { File.join(tmp_dir, "real-path") }
          let(:log_path) { File.join(tmp_dir, "symlink-path") }
          before do
            FileUtils.mkdir_p(real_path)
            File.symlink(real_path, log_path)
          end
          after do
            FileUtils.rm_rf(real_path)
            FileUtils.rm(log_path)
          end

          it "returns real path of log path" do
            expect(log_file_path).to eq(File.join(real_path, "appsignal.log"))
          end
        end
      end
    end
  end

  describe ".system_tmp_dir" do
    before do
      # To counteract the stub in spec_helper
      expect(Appsignal::Config).to receive(:system_tmp_dir).and_call_original
    end

    context "when on a *NIX OS" do
      before do
        expect(Gem).to receive(:win_platform?).and_return(false)
      end

      it "returns the system's tmp dir" do
        expect(described_class.system_tmp_dir).to eq(File.realpath("/tmp"))
      end
    end

    context "when on Microsoft Windows" do
      before do
        expect(Gem).to receive(:win_platform?).and_return(true)
      end

      it "returns the system's tmp dir" do
        expect(described_class.system_tmp_dir).to eq(Dir.tmpdir)
      end
    end
  end

  describe "#validate" do
    subject { config.valid? }
    let(:config) do
      described_class.new(Dir.pwd, "production", config_options)
    end

    describe "push_api_key" do
      let(:config_options) { { :push_api_key => push_api_key, :request_headers => [] } }
      before { config.validate }

      context "with missing push_api_key" do
        let(:push_api_key) { nil }

        it "sets valid to false" do
          is_expected.to eq(false)
        end
      end

      context "with empty push_api_key" do
        let(:push_api_key) { "" }

        it "sets valid to false" do
          is_expected.to eq(false)
        end
      end

      context "with blank push_api_key" do
        let(:push_api_key) { " " }

        it "sets valid to false" do
          is_expected.to eq(false)
        end
      end

      context "with push_api_key present" do
        let(:push_api_key) { "abc" }

        it "sets valid to true" do
          is_expected.to eq(true)
        end
      end
    end
  end

  describe "#log_level" do
    let(:options) { {} }
    let(:config) { described_class.new("", nil, options) }
    subject { config.log_level }

    context "without any config" do
      it "returns info by default" do
        is_expected.to eq(Logger::INFO)
      end
    end

    context "with log_level set to error" do
      let(:options) { { :log_level => "error" } }
      it { is_expected.to eq(Logger::ERROR) }
    end

    context "with log_level set to warn" do
      let(:options) { { :log_level => "warn" } }
      it { is_expected.to eq(Logger::WARN) }
    end

    context "with log_level set to info" do
      let(:options) { { :log_level => "info" } }
      it { is_expected.to eq(Logger::INFO) }
    end

    context "with log_level set to debug" do
      let(:options) { { :log_level => "debug" } }
      it { is_expected.to eq(Logger::DEBUG) }
    end

    context "with log_level set to trace" do
      let(:options) { { :log_level => "trace" } }
      it { is_expected.to eq(Logger::DEBUG) }
    end

    context "with debug and log_level set" do
      let(:options) { { :log_level => "error", :debug => true } }

      it "the log_level option is leading" do
        is_expected.to eq(Logger::ERROR)
      end
    end

    context "with transaction_debug_mode and log_level set" do
      let(:options) { { :log_level => "error", :transaction_debug_mode => true } }

      it "the log_level option is leading" do
        is_expected.to eq(Logger::ERROR)
      end
    end

    context "with log level set to an unknown value" do
      let(:options) { { :log_level => "fatal" } }

      it "prints a warning and doesn't use the log_level" do
        is_expected.to eql(Logger::INFO)
      end
    end
  end

  describe Appsignal::Config::ConfigDSL do
    let(:env) { :production }
    let(:config) { project_fixture_config(env) }
    let(:dsl) { described_class.new(config) }

    describe "default options" do
      let(:env) { :unknown_env }

      it "returns default values for config options" do
        Appsignal::Config::DEFAULT_CONFIG.each do |option, value|
          expect(dsl.send(option)).to eq(value)
        end
      end
    end

    it "returns already set values for config options" do
      ENV["APPSIGNAL_IGNORE_ERRORS"] = "my_error1,my_error2"
      config[:push_api_key] = "my push key"
      config[:ignore_actions] = ["My ignored action"]

      expect(dsl.push_api_key).to eq("my push key")
      expect(dsl.ignore_actions).to eq(["My ignored action"])
      expect(dsl.ignore_errors).to eq(["my_error1", "my_error2"])
    end

    it "returns the env" do
      expect(dsl.env).to eq("production")
    end

    it "sets config options" do
      dsl.push_api_key = "my push key"
      dsl.ignore_actions = ["My ignored action"]

      expect(dsl.push_api_key).to eq("my push key")
      expect(dsl.ignore_actions).to eq(["My ignored action"])
    end

    it "doesn't update the config object" do
      dsl.push_api_key = "my push key"

      expect(dsl.push_api_key).to eq("my push key")
      expect(config[:push_api_key]).to eq("abc") # Loaded from file
    end

    it "casts strings to strings" do
      dsl.activejob_report_errors = :all
      dsl.sidekiq_report_errors = :all

      expect(dsl.activejob_report_errors).to eq("all")
      expect(dsl.sidekiq_report_errors).to eq("all")
    end

    it "casts booleans to booleans" do
      dsl.active = :yes
      dsl.enable_host_metrics = "An object representing a truthy value"
      dsl.send_params = true
      dsl.send_session_data = false

      expect(dsl.active).to be(true)
      expect(dsl.enable_host_metrics).to be(true)
      expect(dsl.send_params).to be(true)
      expect(dsl.send_session_data).to be(false)
    end

    it "casts arrays to arrays" do
      ignore_actions = Set.new
      ignore_actions << "my ignored action 1"
      ignore_actions << "my ignored action 2"
      dsl.ignore_actions = ignore_actions

      expect(dsl.ignore_actions).to eq(["my ignored action 1", "my ignored action 2"])
    end

    it "casts floats to floats" do
      dsl.cpu_count = 1

      expect(dsl.cpu_count).to eq(1.0)
    end
  end
end
