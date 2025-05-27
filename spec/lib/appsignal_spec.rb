describe Appsignal do
  include EnvironmentMetadataHelper
  around { |example| keep_transactions { example.run } }

  let(:transaction) { http_request_transaction }

  describe ".configure" do
    let(:root_path) { tmp_dir }
    before do
      log_dir = File.join(root_path, "log")
      FileUtils.mkdir_p(log_dir)
    end

    context "when started" do
      it "doesn't update the config" do
        start_agent(
          :root_path => root_path,
          :options => { :active => true, :push_api_key => "dummy" }
        )
        Appsignal::Testing.store[:config_called] = false
        expect do
          Appsignal.configure do |_config|
            Appsignal::Testing.store[:config_called] = true
          end
        end.to_not(change { [Appsignal.config, Appsignal.active?] })
        expect(Appsignal::Testing.store[:config_called]).to be(false)
      end

      it "logs a warning" do
        start_agent(
          :root_path => tmp_dir,
          :options => { :active => true, :push_api_key => "dummy" }
        )
        logs =
          capture_logs do
            Appsignal.configure do |_config|
              # Do something
            end
          end
        expect(logs).to contains_log(
          :warn,
          "AppSignal is already started. Ignoring `Appsignal.configure` call."
        )
      end
    end

    context "with config but not started" do
      it "reuses the already loaded config if no env arg is given" do
        Appsignal.configure(:my_env, :root_path => root_path) do |config|
          config.ignore_actions = ["My action"]
        end

        Appsignal.configure do |config|
          expect(config.env).to eq("my_env")
          expect(config.ignore_actions).to eq(["My action"])

          config.active = true
          config.name = "My app"
          config.push_api_key = "key"
        end
        Appsignal.start

        expect(Appsignal.config.valid?).to be(true)
        expect(Appsignal.config.env).to eq("my_env")
        expect(Appsignal.config[:name]).to eq("My app")
        expect(Appsignal.config[:push_api_key]).to eq("key")
        expect(Appsignal.config[:ignore_actions]).to eq(["My action"])
      end

      it "reuses the already loaded config if the env is the same" do
        Appsignal.configure(:my_env, :root_path => root_path) do |config|
          config.ignore_actions = ["My action"]
        end

        Appsignal.configure(:my_env) do |config|
          expect(config.ignore_actions).to eq(["My action"])
          config.active = true
          config.name = "My app"
          config.push_api_key = "key"
        end
        Appsignal.start

        expect(Appsignal.config.valid?).to be(true)
        expect(Appsignal.config.env).to eq("my_env")
        expect(Appsignal.config[:active]).to be(true)
        expect(Appsignal.config[:name]).to eq("My app")
        expect(Appsignal.config[:push_api_key]).to eq("key")
      end

      it "loads a new config if the env is not the same" do
        Appsignal.configure(:my_env, :root_path => root_path) do |config|
          config.name = "Some name"
          config.push_api_key = "Some key"
          config.ignore_actions = ["My action"]
        end

        Appsignal.configure(:my_env2) do |config|
          expect(config.ignore_actions).to be_empty
          config.active = true
          config.name = "My app"
          config.push_api_key = "key"
        end
        Appsignal.start

        expect(Appsignal.config.valid?).to be(true)
        expect(Appsignal.config.env).to eq("my_env2")
        expect(Appsignal.config[:active]).to be(true)
        expect(Appsignal.config[:name]).to eq("My app")
        expect(Appsignal.config[:push_api_key]).to eq("key")
      end

      it "loads a new config if the path is not the same" do
        Appsignal.configure(:my_env, :root_path => "/some/path") do |config|
          config.name = "Some name"
          config.push_api_key = "Some key"
          config.ignore_actions = ["My action"]
        end

        Appsignal.configure(:my_env, :root_path => root_path) do |config|
          expect(config.ignore_actions).to be_empty
          config.active = true
          config.name = "My app"
          config.push_api_key = "key"
        end
        Appsignal.start

        expect(Appsignal.config.valid?).to be(true)
        expect(Appsignal.config.env).to eq("my_env")
        expect(Appsignal.config[:active]).to be(true)
        expect(Appsignal.config[:name]).to eq("My app")
        expect(Appsignal.config[:push_api_key]).to eq("key")
      end

      it "calls configure if not started yet" do
        Appsignal.configure(:my_env) do |config|
          config.active = false
          config.name = "Some name"
        end
        Appsignal.start
        expect(Appsignal.started?).to be_falsy

        Appsignal.configure(:my_env) do |config|
          expect(config.ignore_actions).to be_empty
          config.active = true
          config.name = "My app"
          config.push_api_key = "key"
        end
        Appsignal.start

        expect(Appsignal.config.valid?).to be(true)
        expect(Appsignal.config.env).to eq("my_env")
        expect(Appsignal.config[:active]).to be(true)
        expect(Appsignal.config[:name]).to eq("My app")
        expect(Appsignal.config[:push_api_key]).to eq("key")
      end
    end

    context "when not active" do
      it "starts with the configured config" do
        Appsignal.configure(:test) do |config|
          config.push_api_key = "key"
        end
        Appsignal.start

        expect(Appsignal.config[:push_api_key]).to eq("key")
      end

      it "uses the given env" do
        ENV["APPSIGNAL_APP_ENV"] = "env_env"
        Appsignal.configure(:env_arg)
        Appsignal.start

        expect(Appsignal.config.env).to eq("env_arg")
      end

      it "uses the given root path to read the config file" do
        err_stream = std_stream
        logs =
          capture_logs do
            capture_std_streams(std_stream, err_stream) do
              Appsignal.configure(:test, :root_path => project_fixture_path)
            end
          end
        Appsignal.start

        message = "The `Appsignal.configure` helper is called while a `config/appsignal.yml` " \
          "file is present."
        expect(logs).to contains_log(:warn, message)
        expect(err_stream.read).to include("appsignal WARNING: #{message}")
        expect(Appsignal.config.env).to eq("test")
        expect(Appsignal.config[:push_api_key]).to eq("abc")
        # Ensure it loads from the config file in the given path
        expect(Appsignal.config.file_config).to_not be_empty
      end

      it "loads the config from the YAML file" do
        err_stream = std_stream
        logs =
          capture_logs do
            capture_std_streams(std_stream, err_stream) do
              Dir.chdir project_fixture_path do
                Appsignal.configure(:test)
              end
            end
          end
        Appsignal.start

        message = "The `Appsignal.configure` helper is called while a `config/appsignal.yml` " \
          "file is present."
        expect(logs).to contains_log(:warn, message)
        expect(err_stream.read).to include("appsignal WARNING: #{message}")
        expect(Appsignal.config.env).to eq("test")
        expect(Appsignal.config[:push_api_key]).to eq("abc")
        # Ensure it loads from the config file in the current working directory
        expect(Appsignal.config.file_config).to_not be_empty
      end

      it "allows customization of config in the block" do
        Appsignal.configure(:test) do |config|
          config.activate_if_environment(:test)
          config.push_api_key = "key"
        end
        Appsignal.start

        expect(Appsignal.config.valid?).to be(true)
        expect(Appsignal.config.env).to eq("test")
        expect(Appsignal.config[:push_api_key]).to eq("key")
      end

      it "loads the default config" do
        options = Appsignal::Config::DEFAULT_CONFIG
        if Appsignal::Extension.running_in_container?
          options = options.merge(:enable_at_exit_hook => "always")
        end
        Appsignal.configure do |config|
          options.each do |option, value|
            expect(config.send(option)).to eq(value)
          end
        end
      end

      it "recognizes valid config" do
        Appsignal.configure(:my_env) do |config|
          config.activate_if_environment(:my_env)
          config.push_api_key = "key"
        end
        Appsignal.start

        expect(Appsignal.config.valid?).to be(true)
      end

      it "recognizes invalid config" do
        Appsignal.configure(:my_env) do |config|
          config.activate_if_environment(:my_env)
          config.push_api_key = ""
        end
        Appsignal.start

        expect(Appsignal.config.valid?).to be(false)
      end

      it "sets the environment when given as an argument" do
        Appsignal.configure(:my_env)

        expect(Appsignal.config.env).to eq("my_env")
      end

      it "reads the environment from the environment" do
        ENV["APPSIGNAL_APP_ENV"] = "env_env"
        Appsignal.configure do |config|
          expect(config.env).to eq("env_env")
        end

        expect(Appsignal.config.env).to eq("env_env")
      end

      it "reads config options from the environment" do
        ENV["APPSIGNAL_APP_ENV"] = "env_env"
        ENV["APPSIGNAL_APP_NAME"] = "AppNameFromEnv"
        Appsignal.configure do |config|
          expect(config.env).to eq("env_env")
          expect(config.name).to eq("AppNameFromEnv")
        end

        expect(Appsignal.config.env).to eq("env_env")
        expect(Appsignal.config[:name]).to eq("AppNameFromEnv")
      end

      it "reads the environment from a loader default" do
        clear_integration_env_vars!
        define_loader(:loader_env) do
          def on_load
            register_config_defaults(
              :env => "loader_env"
            )
          end
        end
        load_loader(:loader_env)

        Appsignal.configure do |config|
          expect(config.env).to eq("loader_env")
        end

        expect(Appsignal.config.env).to eq("loader_env")
      end

      it "reads the root_path from a loader default" do
        clear_integration_env_vars!
        define_loader(:loader_path) do
          def on_load
            register_config_defaults(
              :root_path => "/loader_path"
            )
          end
        end
        load_loader(:loader_path)

        Appsignal.configure do |config|
          expect(config.app_path).to eq("/loader_path")
        end

        expect(Appsignal.config.root_path).to eq("/loader_path")
      end

      it "considers the given env leading above APPSIGNAL_APP_ENV" do
        ENV["APPSIGNAL_APP_ENV"] = "env_env"

        Appsignal.configure(:dsl_env) do |config|
          expect(config.env).to eq("dsl_env")
        end

        expect(Appsignal.config.env).to eq("dsl_env")
      end

      it "allows modification of previously unset config options" do
        expect do
          Appsignal.configure do |config|
            config.ignore_actions << "My action"
            config.request_headers << "My allowed header"
          end
        end.to_not(change { Appsignal::Config::DEFAULT_CONFIG })

        expect(Appsignal.config[:ignore_actions]).to eq(["My action"])
        expect(Appsignal.config[:request_headers])
          .to eq(Appsignal::Config::DEFAULT_CONFIG[:request_headers] + ["My allowed header"])
      end
    end
  end

  describe "._load_config!" do
    it "works with envs as symbols" do
      ENV["APPSIGNAL_APP_ENV"] = "_load_config_env"
      Appsignal._load_config!(:production)
      expect(Appsignal.config.env).to eq("production")
    end

    it "ignores zero length string values" do
      ENV["APPSIGNAL_APP_ENV"] = "_load_config_env"
      Appsignal._load_config!("")
      expect(Appsignal.config.env).to eq("_load_config_env")
    end

    it "ignores empty string values" do
      ENV["APPSIGNAL_APP_ENV"] = "_load_config_env"
      Appsignal._load_config!("  ")
      expect(Appsignal.config.env).to eq("_load_config_env")
    end

    it "does not validate if not active for env" do
      ENV["APPSIGNAL_APP_ENV"] = "_custom_env"
      logs = capture_logs { Appsignal._load_config! }
      expect(Appsignal.config.valid?).to be(false)

      expect(logs)
        .to_not contains_log(:error, "Not starting, not active for '_custom_env'")
    end

    it "calls the blocks before validation" do
      called = false
      Appsignal._load_config! do |config|
        config.merge_dsl_options(:active => true)
        # Not yet validated here
        expect(Appsignal.config.valid?).to be(false)

        config.merge_dsl_options(:push_api_key => "abc")
        called = true
      end
      expect(called).to be(true)
      expect(Appsignal.config.valid?).to be(true)
      expect(Appsignal.config.config_hash).to include(:push_api_key => "abc")
    end
  end

  describe ".start" do
    context "with no config set beforehand" do
      let(:stdout_stream) { std_stream }
      let(:stdout) { stdout_stream.read }
      let(:stderr_stream) { std_stream }
      let(:stderr) { stderr_stream.read }
      before { ENV["APPSIGNAL_LOG"] = "stdout" }

      it "does nothing when config is not set and there is no valid config in the env" do
        expect(Appsignal::Extension).to_not receive(:start)
        capture_std_streams(stdout_stream, stderr_stream) { Appsignal.start }

        expect(stdout).to contains_log(:info, "appsignal: Not starting, not active for test")
      end

      it "should create a config from the env" do
        ENV["APPSIGNAL_PUSH_API_KEY"] = "something"
        expect(Appsignal::Extension).to receive(:start)
        capture_std_streams(stdout_stream, stderr_stream) { Appsignal.start }

        expect(Appsignal.config[:push_api_key]).to eq("something")
        expect(stderr).to_not include("[ERROR]")
        expect(stdout).to_not include("[ERROR]")
      end

      it "reads the environment from the loader defaults" do
        clear_integration_env_vars!
        define_loader(:loader_env) do
          def on_load
            register_config_defaults(:env => "loader_env")
          end
        end
        load_loader(:loader_env)

        Appsignal.start

        expect(Appsignal.config.env).to eq("loader_env")
      end

      it "reads the root_path from the loader defaults" do
        define_loader(:loader_path) do
          def on_load
            register_config_defaults(:root_path => "/loader_path")
          end
        end
        load_loader(:loader_path)

        Appsignal.start

        expect(Appsignal.config.root_path).to eq("/loader_path")
      end

      it "chooses APPSIGNAL_APP_ENV over the loader defaults as the default env" do
        clear_integration_env_vars!
        ENV["APPSIGNAL_APP_ENV"] = "env_env"
        define_loader(:loader_env) do
          def on_load
            register_config_defaults(:env => "loader_env")
          end
        end
        load_loader(:loader_env)

        Appsignal.start

        expect(Appsignal.config.env).to eq("env_env")
      end

      it "reads the config/appsignal.rb file if present" do
        test_path = File.join(tmp_dir, "config_file_test_1")
        FileUtils.mkdir_p(test_path)
        Dir.chdir test_path do
          config_contents =
            <<~CONFIG
              Appsignal.configure do |config|
                config.active = false
                config.name = "DSL app"
                config.push_api_key = "config_file_push_api_key"
                config.ignore_actions << "Test"
              end
            CONFIG
          write_file(File.join(test_path, "config", "appsignal.rb"), config_contents)
        end

        ENV["APPSIGNAL_APP_PATH"] = test_path
        Appsignal.start

        expect(Appsignal.dsl_config_file_loaded?).to be(true)
        expect(Appsignal.config.root_path).to eq(test_path)
        expect(Appsignal.config[:active]).to be(false)
        expect(Appsignal.config[:name]).to eq("DSL app")
        expect(Appsignal.config[:push_api_key]).to eq("config_file_push_api_key")
        expect(Appsignal.config[:ignore_actions]).to include("Test")
        expect(Appsignal.config_error?).to be_falsey
        expect(Appsignal.config_error).to be_nil
      ensure
        FileUtils.rm_rf(test_path)
      end

      it "ignores calls to Appsignal.start from config/appsignal.rb" do
        test_path = File.join(tmp_dir, "config_file_test_2")
        FileUtils.mkdir_p(test_path)
        Dir.chdir test_path do
          config_contents =
            <<~CONFIG
              Appsignal.configure do |config|
                config.active = false
                config.name = "DSL app"
              end
              Appsignal.start
            CONFIG
          write_file(File.join(test_path, "config", "appsignal.rb"), config_contents)
        end

        ENV["APPSIGNAL_APP_PATH"] = test_path
        logs = capture_logs { Appsignal.start }

        expect(logs)
          .to contains_log(:warn, "Ignoring call to Appsignal.start in config file context.")
        expect(Appsignal.dsl_config_file_loaded?).to be(true)
        expect(Appsignal.config.root_path).to eq(test_path)
        expect(Appsignal.config[:active]).to be(false)
        expect(Appsignal.config[:name]).to eq("DSL app")
      ensure
        FileUtils.rm_rf(test_path)
      end

      it "only reads from config/appsignal.rb if it and config/appsignal.yml are present" do
        test_path = File.join(tmp_dir, "config_file_test_3")
        FileUtils.mkdir_p(test_path)
        Dir.chdir test_path do
          config_contents =
            <<~CONFIG
              Appsignal.configure(:test) do |config|
                config.active = false
                config.name = "DSL app"
                config.push_api_key = "config_file_push_api_key"
              end
            CONFIG
          write_file(File.join(test_path, "config", "appsignal.rb"), config_contents)

          yaml_contents =
            <<~YAML
              test:
                active: true
                name: "YAML app"
                ignore_errors: ["YAML error"]
            YAML
          write_file(File.join(test_path, "config", "appsignal.yml"), yaml_contents)
        end

        ENV["APPSIGNAL_APP_PATH"] = test_path
        err_stream = std_stream
        logs =
          capture_logs do
            capture_std_streams(std_stream, err_stream) do
              Appsignal.start
            end
          end

        warning_message = "Both a Ruby and YAML configuration file are found."
        expect(logs).to contains_log(:warn, warning_message)
        expect(err_stream.read).to include("appsignal WARNING: #{warning_message}")
        expect(Appsignal.dsl_config_file_loaded?).to be(true)
        expect(Appsignal.config.root_path).to eq(test_path)
        expect(Appsignal.config[:active]).to be(false)
        expect(Appsignal.config[:name]).to eq("DSL app")
        expect(Appsignal.config[:push_api_key]).to eq("config_file_push_api_key")
        expect(Appsignal.config[:ignore_errors]).to_not include("YAML error")
      ensure
        FileUtils.rm_rf(test_path)
      end

      it "only reads from config/appsignal.rb even if it's empty" do
        test_path = File.join(tmp_dir, "config_file_test_3")
        FileUtils.mkdir_p(test_path)
        Dir.chdir test_path do
          config_contents = "# I am empty!"
          write_file(File.join(test_path, "config", "appsignal.rb"), config_contents)

          yaml_contents =
            <<~YAML
              test:
                active: true
                name: "YAML app"
                ignore_errors: ["YAML error"]
            YAML
          write_file(File.join(test_path, "config", "appsignal.yml"), yaml_contents)
        end

        ENV["APPSIGNAL_APP_PATH"] = test_path
        Appsignal.start

        expect(Appsignal.dsl_config_file_loaded?).to be(true)
        # No Appsignal.configure was called, so it's misconfigured, but it
        # shouldn't fall back on the YAML file.
        expect(Appsignal.config[:active]).to be(false)
        expect(Appsignal.config[:name]).to be_nil
        expect(Appsignal.config[:ignore_errors]).to be_empty
      ensure
        FileUtils.rm_rf(test_path)
      end

      it "options set in config/appsignal.rb are leading" do
        test_path = File.join(tmp_dir, "config_file_test_4")
        FileUtils.mkdir_p(test_path)
        Dir.chdir test_path do
          config_contents =
            <<~CONFIG
              Appsignal.configure(:test) do |config|
                config.active = true
                config.name = "DSL app"
                config.push_api_key = "config_file_push_api_key"
              end
            CONFIG
          write_file(File.join(test_path, "config", "appsignal.rb"), config_contents)
        end

        ENV["APPSIGNAL_APP_PATH"] = test_path
        # These env vars should not be used as the config option values
        ENV["APPSIGNAL_APP_ENV"] = "env_env"
        ENV["APPSIGNAL_APP_NAME"] = "env_name"
        ENV["APPSIGNAL_PUSH_API_KEY"] = "env_push_api_key"
        Appsignal.start

        expect(Appsignal.dsl_config_file_loaded?).to be(true)
        expect(Appsignal.config.root_path).to eq(test_path)
        expect(Appsignal.config.env).to eq("test")
        expect(Appsignal.config[:active]).to be(true)
        expect(Appsignal.config[:name]).to eq("DSL app")
        expect(Appsignal.config[:push_api_key]).to eq("config_file_push_api_key")
      ensure
        FileUtils.rm_rf(test_path)
      end

      it "doesn't start if config/appsignal.rb raised an error" do
        test_path = File.join(tmp_dir, "config_file_test_5")
        FileUtils.mkdir_p(test_path)
        Dir.chdir test_path do
          config_contents =
            <<~CONFIG
              Appsignal.configure do |config|
                config.active = true
                config.name = "DSL app"
                config.push_api_key = "config_file_push_api_key"
              end
              raise "uh oh" # Deliberatly crash
            CONFIG
          write_file(File.join(test_path, "config", "appsignal.rb"), config_contents)
        end

        ENV["APPSIGNAL_APP_PATH"] = test_path
        err_stream = std_stream
        logs =
          capture_std_streams(std_stream, err_stream) do
            capture_logs do
              Appsignal.start
            end
          end

        message =
          "Not starting AppSignal because an error occurred while loading the " \
            "AppSignal config file.\n" \
            "File: \"#{File.join(test_path, "config/appsignal.rb")}\"\n" \
            "RuntimeError: uh oh\n"
        expect(logs).to contains_log(:error, message)
        expect(err_stream.read).to include("appsignal ERROR: #{message}")
        expect(Appsignal.dsl_config_file_loaded?).to be(true)
        expect(Appsignal.config.root_path).to eq(test_path)
        expect(Appsignal.config[:active]).to be(false) # Disables the config on error
        expect(Appsignal.config[:name]).to eq("DSL app")
        expect(Appsignal.config[:push_api_key]).to eq("config_file_push_api_key")
        expect(Appsignal.config_error?).to be_truthy
        expect(Appsignal.config_error).to be_kind_of(RuntimeError)
      ensure
        FileUtils.rm_rf(test_path)
      end
    end

    context "when config is loaded" do
      let(:options) { {} }
      before do
        configure(
          :env => :production,
          :root_path => project_fixture_path,
          :options => options
        )
      end

      it "should initialize logging" do
        Appsignal.start
        expect(Appsignal.internal_logger.level).to eq Logger::INFO
      end

      it "should start native" do
        expect(Appsignal::Extension).to receive(:start)
        Appsignal.start
      end

      it "freezes the config" do
        Appsignal.start

        expect_frozen_error do
          Appsignal.config[:ignore_actions] << "my action"
        end
        expect_frozen_error do
          Appsignal.config[:ignore_actions] << "my action"
        end
        expect_frozen_error do
          Appsignal.config.config_hash.merge!(:option => :value)
        end
        expect_frozen_error do
          Appsignal.config[:ignore_actions] = "my action"
        end
      end

      def expect_frozen_error(&block)
        expect(&block).to raise_error(FrozenError)
      end

      context "when allocation tracking has been enabled" do
        let(:options) { { :enable_allocation_tracking => true } }
        before do
          capture_environment_metadata_report_calls
        end

        unless DependencyHelper.running_jruby?
          it "installs the allocation event hook" do
            expect(Appsignal::Extension).to receive(:install_allocation_event_hook)
              .and_call_original
            Appsignal.start
            expect_environment_metadata("ruby_allocation_tracking_enabled", "true")
          end
        end
      end

      context "when allocation tracking has been disabled" do
        let(:options) { { :enable_allocation_tracking => false } }
        before do
          capture_environment_metadata_report_calls
        end

        it "doesn't install the allocation event hook" do
          expect(Appsignal::Extension).not_to receive(:install_allocation_event_hook)
          Appsignal.start
          expect_not_environment_metadata("ruby_allocation_tracking_enabled")
        end
      end

      context "when minutely metrics has been enabled" do
        let(:options) { { :enable_minutely_probes => true } }

        it "starts minutely probes" do
          expect(Appsignal::Probes).to receive(:start)
          Appsignal.start
        end
      end

      context "when minutely metrics has been disabled" do
        let(:options) { { :enable_minutely_probes => false } }

        it "does not start minutely probes" do
          expect(Appsignal::Probes).to_not receive(:start)
          Appsignal.start
        end
      end

      describe "loaders" do
        it "starts loaded loaders" do
          Appsignal::Testing.store[:loader_loaded] = 0
          Appsignal::Testing.store[:loader_started] = 0
          define_loader(:start_loader) do
            def on_load
              Appsignal::Testing.store[:loader_loaded] += 1
            end

            def on_start
              Appsignal::Testing.store[:loader_started] += 1
            end
          end
          Appsignal::Loaders.load(:start_loader)
          Appsignal::Loaders.start

          expect(Appsignal::Testing.store[:loader_loaded]).to eq(1)
          expect(Appsignal::Testing.store[:loader_started]).to eq(1)
        end
      end

      describe "environment metadata" do
        before { capture_environment_metadata_report_calls }

        it "collects and reports environment metadata" do
          Appsignal.start
          expect_environment_metadata("ruby_version", "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}")
          expect_environment_metadata("ruby_engine", RUBY_ENGINE)
          if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.3.0")
            expect_environment_metadata("ruby_engine_version", RUBY_ENGINE_VERSION)
          end
        end
      end

      it "doesn't load config/appsignal.rb if Appsignal.configure was called beforehand" do
        Appsignal.configure do |config|
          config.active = false
          config.name = "DSL app"
          config.push_api_key = "dsl_push_api_key"
        end

        test_path = File.join(tmp_dir, "config_file_test_5")
        FileUtils.mkdir_p(test_path)
        config_file_path = File.join(test_path, "config", "appsignal.rb")
        Dir.chdir test_path do
          config_contents =
            <<~CONFIG
              Appsignal.configure do |config|
                config.active = false
                config.name = "DSL app"
                config.push_api_key = "config_file_push_api_key"
              end
            CONFIG
          write_file(config_file_path, config_contents)
        end

        ENV["APPSIGNAL_APP_PATH"] = test_path
        err_stream = std_stream
        logs =
          capture_logs do
            capture_std_streams(std_stream, err_stream) do
              Appsignal.start
            end
          end

        message = "The `Appsignal.configure` helper is called from within an " \
          "app while a `#{config_file_path}` file is present."
        expect(logs).to contains_log(:warn, message)
        expect(err_stream.read).to include("appsignal WARNING: #{message}")
        expect(Appsignal.dsl_config_file_loaded?).to be(false)
        expect(Appsignal.config.root_path).to eq(project_fixture_path)
        expect(Appsignal.config[:active]).to be(false)
        expect(Appsignal.config[:name]).to eq("DSL app")
        expect(Appsignal.config[:push_api_key]).to eq("dsl_push_api_key")
      ensure
        FileUtils.rm_rf(test_path)
      end
    end

    context "when already started" do
      it "doesn't start again" do
        start_agent

        expect(Appsignal::Extension).to_not receive(:start)
        logs = capture_logs { Appsignal.start }
        expect(logs).to contains_log(
          :warn,
          "Ignoring call to Appsignal.start after AppSignal has started"
        )
      end
    end

    context "with debug logging" do
      before { Appsignal.configure(:test, :root_path => project_fixture_path) }

      it "should change the log level" do
        Appsignal.start
        expect(Appsignal.internal_logger.level).to eq Logger::DEBUG
      end
    end
  end

  describe ".load" do
    before do
      stub_const("TestLoader", define_loader(:appsignal_loader))
    end

    it "loads a loader" do
      expect(Appsignal::Loaders.instances).to be_empty
      Appsignal.load(:appsignal_loader)
      expect(Appsignal::Loaders.instances)
        .to include(:appsignal_loader => instance_of(TestLoader))
    end
  end

  describe ".forked" do
    context "when not active" do
      it "does nothing" do
        expect(Appsignal::Extension).to_not receive(:start)

        Appsignal.forked
      end
    end

    context "when active" do
      before do
        Appsignal.configure(:production, :root_path => project_fixture_path)
        Appsignal.start
      end

      it "starts the logger and extension" do
        expect(Appsignal).to receive(:_start_logger)
        expect(Appsignal::Extension).to receive(:start)

        Appsignal.forked
      end
    end
  end

  describe ".stop" do
    it "calls stop on the extension" do
      expect(Appsignal.internal_logger).to receive(:info).with("Stopping AppSignal")
      expect(Appsignal::Extension).to receive(:stop)
      Appsignal.stop
      expect(Appsignal.active?).to be_falsy
    end

    it "stops the minutely probes" do
      Appsignal::Probes.start
      expect(Appsignal::Probes.started?).to be_truthy
      Appsignal.stop
      expect(Appsignal::Probes.started?).to be_falsy
    end

    context "with context specified" do
      it "should log the context" do
        expect(Appsignal.internal_logger).to receive(:info).with("Stopping AppSignal (something)")
        expect(Appsignal::Extension).to receive(:stop)
        Appsignal.stop("something")
        expect(Appsignal.active?).to be_falsy
      end
    end

    it "calls stop on the check-in scheduler" do
      expect(Appsignal::CheckIn.scheduler).to receive(:stop)
      Appsignal.stop
    end
  end

  describe ".started?" do
    subject { Appsignal.started? }

    context "when started with active config" do
      before { start_agent }

      it { is_expected.to be_truthy }
    end

    context "when started with inactive config" do
      before { Appsignal.configure(:nonsense, :root_path => project_fixture_path) }

      it { is_expected.to be_falsy }
    end
  end

  describe ".active?" do
    subject { Appsignal.active? }

    context "without config" do
      it { is_expected.to be_falsy }
    end

    context "with inactive config" do
      before do
        Appsignal.configure(:nonsense, :root_path => project_fixture_path)
        Appsignal.start
      end

      it { is_expected.to be_falsy }
    end

    context "with active config" do
      before do
        Appsignal.configure(:production, :root_path => project_fixture_path)
        Appsignal.start
      end

      it { is_expected.to be_truthy }
    end
  end

  describe ".add_exception" do
    it "should alias this method" do
      expect(Appsignal).to respond_to(:add_exception)
    end
  end

  describe ".get_server_state" do
    it "should call server state on the extension" do
      expect(Appsignal::Extension).to receive(:get_server_state).with("key")

      Appsignal.get_server_state("key")
    end

    it "should get nil by default" do
      expect(Appsignal.get_server_state("key")).to be_nil
    end
  end

  context "not active" do
    before do
      Appsignal.configure(:not_active, :root_path => project_fixture_path)
      Appsignal.start
    end

    describe ".send_error" do
      let(:error) { ExampleException.new("specific error") }

      it "does not raise an error" do
        Appsignal.send_error(error)
      end

      it "does not create a transaction" do
        expect do
          Appsignal.send_error(error)
        end.to_not(change { created_transactions.count })
      end
    end

    describe ".set_error" do
      let(:error) { ExampleException.new("specific error") }

      it "does not raise an error" do
        Appsignal.set_error(error)
      end

      it "does not create a transaction" do
        expect do
          Appsignal.set_error(error)
        end.to_not(change { created_transactions.count })
      end
    end

    describe ".report_error" do
      let(:error) { ExampleException.new("specific error") }

      it "does not raise an error" do
        Appsignal.report_error(error)
      end

      it "does not create a transaction" do
        expect do
          Appsignal.report_error(error)
        end.to_not(change { created_transactions.count })
      end
    end

    describe ".set_namespace" do
      it "does not raise an error" do
        Appsignal.set_namespace("custom")
      end
    end

    describe ".tag_request" do
      it "does not raise an error" do
        Appsignal.tag_request(:tag => "tag")
      end
    end

    describe ".set_custom_data" do
      it "does not raise an error" do
        Appsignal.set_custom_data(:data => "value")
      end
    end
  end

  context "with config and started" do
    before { start_agent }
    around { |example| keep_transactions { example.run } }

    describe ".monitor" do
      it "creates a transaction" do
        expect do
          Appsignal.monitor(:action => "MyAction")
        end.to(change { created_transactions.count }.by(1))

        transaction = last_transaction
        expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        expect(transaction).to have_action("MyAction")
        expect(transaction).to_not have_error
        expect(transaction).to_not include_events
        expect(transaction).to_not have_queue_start
        expect(transaction).to be_completed
      end

      it "returns the block's return value" do
        expect(Appsignal.monitor(:action => nil) { :return_value }).to eq(:return_value)
      end

      it "sets a custom namespace via the namespace argument" do
        Appsignal.monitor(:namespace => "custom", :action => nil)

        expect(last_transaction).to have_namespace("custom")
      end

      it "doesn't overwrite custom namespace set in the block" do
        Appsignal.monitor(:namespace => "custom", :action => nil) do
          Appsignal.set_namespace("more custom")
        end

        expect(last_transaction).to have_namespace("more custom")
      end

      it "sets the action via the action argument using a string" do
        Appsignal.monitor(:action => "custom")

        expect(last_transaction).to have_action("custom")
      end

      it "sets the action via the action argument using a symbol" do
        Appsignal.monitor(:action => :custom)

        expect(last_transaction).to have_action("custom")
      end

      it "doesn't overwrite custom action set in the block" do
        Appsignal.monitor(:action => "custom") do
          Appsignal.set_action("more custom")
        end

        expect(last_transaction).to have_action("more custom")
      end

      it "doesn't set the action when value is nil" do
        Appsignal.monitor(:action => nil)

        expect(last_transaction).to_not have_action
      end

      it "doesn't set the action when value is :set_later" do
        Appsignal.monitor(:action => :set_later)

        expect(last_transaction).to_not have_action
      end

      it "reports exceptions that occur in the block" do
        expect do
          Appsignal.monitor :action => nil do
            raise ExampleException, "error message"
          end
        end.to raise_error(ExampleException, "error message")

        expect(last_transaction).to have_error("ExampleException", "error message")
      end

      context "with already active transction" do
        let(:err_stream) { std_stream }
        let(:stderr) { err_stream.read }
        let(:transaction) { http_request_transaction }
        before do
          set_current_transaction(transaction)
          transaction.set_action("My action")
        end

        it "doesn't create a new transaction" do
          logs = nil
          expect do
            logs =
              capture_logs do
                capture_std_streams(std_stream, err_stream) do
                  Appsignal.monitor(:action => nil)
                end
              end
          end.to_not(change { created_transactions.count })

          warning = "A transaction is active around this 'Appsignal.monitor' call."
          expect(logs).to contains_log(:warn, warning)
          expect(stderr).to include("appsignal WARNING: #{warning}")
        end

        it "does not overwrite the parent transaction's namespace" do
          silence { Appsignal.monitor(:namespace => "custom", :action => nil) }

          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        end

        it "does not overwrite the parent transaction's action" do
          silence { Appsignal.monitor(:action => "custom") }

          expect(transaction).to have_action("My action")
        end

        it "doesn't complete the parent transaction" do
          silence { Appsignal.monitor(:action => nil) }

          expect(transaction).to_not be_completed
        end
      end
    end

    describe ".monitor_and_stop" do
      it "calls Appsignal.stop after the block" do
        allow(Appsignal).to receive(:stop)
        err_stream = std_stream
        logs =
          capture_logs do
            capture_std_streams(std_stream, err_stream) do
              Appsignal.monitor_and_stop(:namespace => "custom", :action => "My Action")
            end
          end

        transaction = last_transaction
        expect(transaction).to have_namespace("custom")
        expect(transaction).to have_action("My Action")
        expect(transaction).to be_completed

        expect(Appsignal).to have_received(:stop).with("monitor_and_stop")
        message = "The `Appsignal.monitor_and_stop` helper is deprecated."
        expect(logs).to contains_log(:warn, message)
        expect(err_stream.read).to include("appsignal WARNING: #{message}")
      end

      it "passes the block to Appsignal.monitor" do
        expect do |blk|
          silence do
            Appsignal.monitor_and_stop(:action => "My action", &blk)
          end
        end.to yield_control
      end
    end

    describe ".tag_request" do
      before { start_agent }

      context "with transaction" do
        let(:transaction) { http_request_transaction }
        before { set_current_transaction(transaction) }

        it "sets tags on the current transaction" do
          Appsignal.tag_request("a" => "b")

          transaction._sample
          expect(transaction).to include_tags("a" => "b")
        end
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "does not set tags on the transaction" do
          expect(Appsignal.tag_request).to be_falsy
          Appsignal.tag_request("a" => "b")

          expect_any_instance_of(Appsignal::Transaction).to_not receive(:set_tags)
        end
      end

      it "also listens to tag_job" do
        expect(Appsignal.method(:tag_job)).to eq(Appsignal.method(:tag_request))
      end

      it "also listens to set_tags" do
        expect(Appsignal.method(:set_tags)).to eq(Appsignal.method(:tag_request))
      end
    end

    describe ".add_params" do
      before { start_agent }

      it "has a .set_params alias" do
        expect(Appsignal.method(:add_params)).to eq(Appsignal.method(:set_params))
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }
        before { set_current_transaction(transaction) }

        it "adds parameters to the transaction" do
          Appsignal.add_params("param1" => "value1")

          transaction._sample
          expect(transaction).to include_params("param1" => "value1")
        end

        it "merges the params if called multiple times" do
          Appsignal.add_params("param1" => "value1")
          Appsignal.add_params("param2" => "value2")

          transaction._sample
          expect(transaction).to include_params(
            "param1" => "value1",
            "param2" => "value2"
          )
        end

        it "adds parameters with a block to the transaction" do
          Appsignal.add_params { { "param1" => "value1" } }

          transaction._sample
          expect(transaction).to include_params("param1" => "value1")
        end
      end

      context "without transaction" do
        it "does not add tags to any transaction" do
          Appsignal.add_params("a" => "b")

          expect_any_instance_of(Appsignal::Transaction).to_not receive(:add_params)
        end
      end
    end

    describe ".set_empty_params!" do
      before { start_agent }

      context "with transaction" do
        let(:transaction) { http_request_transaction }
        before { set_current_transaction(transaction) }

        it "marks parameters to be sent as an empty value" do
          Appsignal.add_params("key1" => "value")
          Appsignal.set_empty_params!

          transaction._sample
          expect(transaction).to_not include_params
        end
      end
    end

    describe ".add_session_data" do
      before { start_agent }

      it "has a .set_session_data alias" do
        expect(Appsignal.method(:add_session_data)).to eq(Appsignal.method(:set_session_data))
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }
        before { set_current_transaction(transaction) }

        it "adds session data to the transaction" do
          Appsignal.add_session_data("data" => "value1")

          transaction._sample
          expect(transaction).to include_session_data("data" => "value1")
        end

        it "merges the session data if called multiple times" do
          Appsignal.set_session_data("data1" => "value1")
          Appsignal.set_session_data("data2" => "value2")

          transaction._sample
          expect(transaction).to include_session_data(
            "data1" => "value1",
            "data2" => "value2"
          )
        end

        it "adds session data with a block to the transaction" do
          Appsignal.set_session_data { { "data" => "value1" } }

          transaction._sample
          expect(transaction).to include_session_data("data" => "value1")
        end
      end

      context "without transaction" do
        it "does not add session data to any transaction" do
          Appsignal.set_session_data("a" => "b")

          expect_any_instance_of(Appsignal::Transaction).to_not receive(:add_session_data)
        end
      end
    end

    describe ".add_headers" do
      before { start_agent }

      it "has a .set_headers alias" do
        expect(Appsignal.method(:add_headers)).to eq(Appsignal.method(:set_headers))
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }
        before { set_current_transaction(transaction) }

        it "adds request headers to the transaction" do
          Appsignal.add_headers("PATH_INFO" => "/some-path")

          transaction._sample
          expect(transaction).to include_environment("PATH_INFO" => "/some-path")
        end

        it "merges the request headers if called multiple times" do
          Appsignal.add_headers("PATH_INFO" => "/some-path")
          Appsignal.add_headers("REQUEST_METHOD" => "GET")

          transaction._sample
          expect(transaction).to include_environment(
            "PATH_INFO" => "/some-path",
            "REQUEST_METHOD" => "GET"
          )
        end

        it "adds request headers with a block to the transaction" do
          Appsignal.add_headers { { "PATH_INFO" => "/some-path" } }

          transaction._sample
          expect(transaction).to include_environment("PATH_INFO" => "/some-path")
        end
      end

      context "without transaction" do
        it "does not add request headers to any transaction" do
          Appsignal.add_headers("PATH_INFO" => "/some-path")

          expect_any_instance_of(Appsignal::Transaction).to_not receive(:add_headers)
        end
      end
    end

    describe ".add_custom_data" do
      before { start_agent }

      it "has a .set_custom_data alias" do
        expect(Appsignal.method(:add_custom_data)).to eq(Appsignal.method(:set_custom_data))
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }
        before { set_current_transaction transaction }

        it "adds custom data to the current transaction" do
          Appsignal.add_custom_data(
            :user => { :id => 123 },
            :organization => { :slug => "appsignal" }
          )

          transaction._sample
          expect(transaction).to include_custom_data(
            "user" => { "id" => 123 },
            "organization" => { "slug" => "appsignal" }
          )
        end

        it "merges the custom data if called multiple times" do
          Appsignal.add_custom_data(:abc => "value")
          Appsignal.add_custom_data(:def => "value")

          transaction._sample
          expect(transaction).to include_custom_data(
            "abc" => "value",
            "def" => "value"
          )
        end
      end

      context "without transaction" do
        it "does not add tags any the transaction" do
          Appsignal.add_custom_data(
            :user => { :id => 123 },
            :organization => { :slug => "appsignal" }
          )

          expect_any_instance_of(Appsignal::Transaction).to_not receive(:add_custom_data)
        end
      end
    end

    describe ".add_breadcrumb" do
      before { start_agent }

      context "with transaction" do
        let(:transaction) { http_request_transaction }
        before { set_current_transaction(transaction) }

        it "adds the breadcrumb to the transaction" do
          Appsignal.add_breadcrumb(
            "Network",
            "http",
            "User made network request",
            { :response => 200 },
            fixed_time
          )

          transaction._sample
          expect(transaction).to include_breadcrumb(
            "http",
            "Network",
            "User made network request",
            { "response" => 200 },
            fixed_time
          )
        end
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "does not add a breadcrumb to any transaction" do
          expect(Appsignal.add_breadcrumb("Network", "http")).to be_falsy
        end
      end
    end

    describe "custom metrics" do
      let(:tags) { { :foo => "bar" } }

      describe ".set_gauge" do
        it "should call set_gauge on the extension with a string key and float" do
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 0.1, Appsignal::Extension.data_map_new)
          Appsignal.set_gauge("key", 0.1)
        end

        it "should call set_gauge with tags" do
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 0.1, Appsignal::Utils::Data.generate(tags))
          Appsignal.set_gauge("key", 0.1, tags)
        end

        it "should call set_gauge on the extension with a symbol key and int" do
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 1.0, Appsignal::Extension.data_map_new)
          Appsignal.set_gauge(:key, 1)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:set_gauge).with(
            "key",
            10,
            Appsignal::Extension.data_map_new
          ).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("The gauge value '10' for metric 'key' is too big")

          Appsignal.set_gauge("key", 10)
        end
      end

      describe ".increment_counter" do
        it "should call increment_counter on the extension with a string key" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 1, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter("key")
        end

        it "should call increment_counter with tags" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 1, Appsignal::Utils::Data.generate(tags))
          Appsignal.increment_counter("key", 1, tags)
        end

        it "should call increment_counter on the extension with a symbol key" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 1, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter(:key)
        end

        it "should call increment_counter on the extension with a count" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 5, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter("key", 5)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 10, Appsignal::Extension.data_map_new).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("The counter value '10' for metric 'key' is too big")

          Appsignal.increment_counter("key", 10)
        end
      end

      describe ".add_distribution_value" do
        it "should call add_distribution_value on the extension with a string key and float" do
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 0.1, Appsignal::Extension.data_map_new)
          Appsignal.add_distribution_value("key", 0.1)
        end

        it "should call add_distribution_value with tags" do
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 0.1, Appsignal::Utils::Data.generate(tags))
          Appsignal.add_distribution_value("key", 0.1, tags)
        end

        it "should call add_distribution_value on the extension with a symbol key and int" do
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 1.0, Appsignal::Extension.data_map_new)
          Appsignal.add_distribution_value(:key, 1)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 10, Appsignal::Extension.data_map_new).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("The distribution value '10' for metric 'key' is too big")

          Appsignal.add_distribution_value("key", 10)
        end
      end
    end

    describe ".internal_logger" do
      subject { Appsignal.internal_logger }

      it { is_expected.to be_a Logger }
    end

    describe ".log_formatter" do
      subject { Appsignal.log_formatter.call("Debug", Time.parse("2015-07-08"), nil, "log line") }

      it "formats a log" do
        expect(subject).to eq "[2015-07-08T00:00:00 (process) ##{Process.pid}][Debug] log line\n"
      end

      context "with prefix" do
        subject do
          Appsignal.log_formatter("prefix").call("Debug", Time.parse("2015-07-08"), nil, "log line")
        end

        it "adds a prefix" do
          expect(subject)
            .to eq "[2015-07-08T00:00:00 (process) ##{Process.pid}][Debug] prefix: log line\n"
        end
      end
    end

    describe ".config" do
      subject { Appsignal.config }

      it { is_expected.to be_a Appsignal::Config }
      it "should return configuration" do
        expect(subject[:endpoint]).to eq "https://push.appsignal.com"
      end
    end

    describe ".send_error" do
      let(:error) { ExampleException.new("error message") }
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      around do |example|
        keep_transactions { example.run }
      end

      it "sends the error to AppSignal" do
        expect { Appsignal.send_error(error) }.to(change { created_transactions.count }.by(1))

        transaction = last_transaction
        expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        expect(transaction).to_not have_action
        expect(transaction).to have_error("ExampleException", "error message")
        expect(transaction).to_not include_tags
        expect(transaction).to be_completed
      end

      context "when given error is not an Exception" do
        let(:error) { "string value" }

        it "logs an error message" do
          logs = capture_logs { Appsignal.send_error(error) }
          expect(logs).to contains_log(
            :error,
            "Appsignal.send_error: Cannot send error. " \
              "The given value is not an exception: #{error.inspect}"
          )
        end

        it "does not send the error" do
          expect { Appsignal.send_error(error) }.to_not(change { created_transactions.count })
        end
      end

      context "when given a block" do
        it "yields the transaction and allows additional metadata to be set" do
          Appsignal.send_error(StandardError.new("my_error")) do |transaction|
            transaction.set_action("my_action")
            transaction.set_namespace("my_namespace")
          end

          expect(last_transaction).to have_namespace("my_namespace")
          expect(last_transaction).to have_action("my_action")
          expect(last_transaction).to have_error("StandardError", "my_error")
        end

        it "yields and allows additional metadata to be set with global helpers" do
          Appsignal.send_error(StandardError.new("my_error")) do
            Appsignal.set_action("my_action")
            Appsignal.set_namespace("my_namespace")
          end

          expect(last_transaction).to have_namespace("my_namespace")
          expect(last_transaction).to have_action("my_action")
          expect(last_transaction).to have_error("StandardError", "my_error")
        end

        it "yields to set metadata and doesn't modify the active transaction" do
          active_transaction = http_request_transaction
          active_transaction.set_action("active action")
          active_transaction.set_namespace("active namespace")
          set_current_transaction(active_transaction)
          expect(current_transaction).to eq(active_transaction)

          Appsignal.send_error(StandardError.new("my_error")) do
            Appsignal.set_action("my_action")
            Appsignal.set_namespace("my_namespace")
          end

          # Restores the active_transaction as the current transaction
          expect(current_transaction).to eq(active_transaction)

          expect(last_transaction).to have_namespace("my_namespace")
          expect(last_transaction).to have_action("my_action")
          expect(last_transaction).to have_error("StandardError", "my_error")
          expect(last_transaction).to be_completed

          expect(active_transaction).to have_namespace("active namespace")
          expect(active_transaction).to have_action("active action")
          expect(active_transaction).to_not be_completed
        end
      end
    end

    describe ".set_error" do
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      let(:error) { ExampleException.new("I am an exception") }
      let(:transaction) { http_request_transaction }
      around { |example| keep_transactions { example.run } }

      context "when there is an active transaction" do
        before { set_current_transaction(transaction) }

        it "adds the error to the active transaction" do
          Appsignal.set_error(error)

          transaction._sample
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(transaction).to have_error("ExampleException", "I am an exception")
          expect(transaction).to_not include_tags
        end

        context "when the error is not an Exception" do
          let(:error) { Object.new }

          it "does not set an error" do
            silence { Appsignal.set_error(error) }

            transaction._sample
            expect(transaction).to_not have_error
            expect(transaction).to_not include_tags
          end

          it "logs an error" do
            logs = capture_logs { Appsignal.set_error(error) }
            expect(logs).to contains_log(
              :error,
              "Appsignal.set_error: Cannot set error. " \
                "The given value is not an exception: #{error.inspect}"
            )
          end
        end

        context "when given a block" do
          it "yields the transaction and allows additional metadata to be set" do
            Appsignal.set_error(StandardError.new("my_error")) do |t|
              t.set_action("my_action")
              t.set_namespace("my_namespace")
            end

            expect(transaction).to have_namespace("my_namespace")
            expect(transaction).to have_action("my_action")
            expect(transaction).to have_error("StandardError", "my_error")
          end
        end
      end

      context "when there is no active transaction" do
        it "does nothing" do
          Appsignal.set_error(error)

          expect(transaction).to_not have_error
        end
      end
    end

    describe ".report_error" do
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      let(:error) { ExampleException.new("error message") }
      before { start_agent }
      around { |example| keep_transactions { example.run } }

      context "when the error is not an Exception" do
        let(:error) { Object.new }

        it "does not set an error" do
          silence { Appsignal.report_error(error) }

          expect(last_transaction).to_not have_error
        end

        it "logs an error" do
          logs = capture_logs { Appsignal.report_error(error) }
          expect(logs).to contains_log(
            :error,
            "Appsignal.report_error: Cannot add error. " \
              "The given value is not an exception: #{error.inspect}"
          )
        end
      end

      context "when there is no active transaction" do
        it "creates a new transaction" do
          expect do
            Appsignal.report_error(error)
          end.to(change { created_transactions.count }.by(1))
        end

        it "completes the transaction" do
          Appsignal.report_error(error)

          expect(last_transaction).to be_completed
        end

        context "when given a block" do
          it "yields the transaction and allows additional metadata to be set" do
            Appsignal.report_error(error) do |t|
              t.set_action("my_action")
              t.set_namespace("my_namespace")
              t.set_tags(:tag1 => "value1")
            end

            transaction = last_transaction
            expect(transaction).to have_namespace("my_namespace")
            expect(transaction).to have_action("my_action")
            expect(transaction).to have_error("ExampleException", "error message")
            expect(transaction).to include_tags("tag1" => "value1")
            expect(transaction).to be_completed
          end

          it "yields and allows additional metadata to be set with the global helpers" do
            Appsignal.report_error(error) do
              Appsignal.set_action("my_action")
              Appsignal.set_namespace("my_namespace")
              Appsignal.set_tags(:tag1 => "value1")
            end

            transaction = last_transaction
            expect(transaction).to have_namespace("my_namespace")
            expect(transaction).to have_action("my_action")
            expect(transaction).to have_error("ExampleException", "error message")
            expect(transaction).to include_tags("tag1" => "value1")
            expect(transaction).to be_completed
          end
        end
      end

      context "when there is an active transaction" do
        let(:transaction) { http_request_transaction }
        before { set_current_transaction(transaction) }

        it "sets the error in the active transaction" do
          Appsignal.report_error(error)

          expect(last_transaction).to eq(transaction)
          transaction._sample
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(transaction).to have_error("ExampleException", "error message")
        end

        context "when the active transaction already has an error" do
          let(:previous_error) { ExampleException.new("previous error message") }

          before { transaction.set_error(previous_error) }

          it "does not overwrite the existing set error" do
            Appsignal.report_error(error)

            transaction._sample
            expect(transaction).to have_error("ExampleException", "previous error message")
          end

          it "adds the error to the errors" do
            Appsignal.report_error(error)

            expect(transaction.error_blocks).to eq({ error => [], previous_error => [] })
          end

          context "when given a block" do
            it "only applies the block to the transaction for that error" do
              Appsignal.report_error(error) do |t|
                t.set_action("my_action")
              end

              transaction.complete
              expect(transaction).to have_error("ExampleException", "previous error message")
              expect(transaction).not_to have_action("my_action")

              expect(last_transaction).to_not be(transaction)
              expect(last_transaction).to have_error("ExampleException", "error message")
              expect(last_transaction).to have_action("my_action")
            end
          end
        end

        it "does not complete the transaction" do
          Appsignal.report_error(error)

          expect(last_transaction).to_not be_completed
        end

        context "when given a block" do
          before do
            Appsignal.report_error(error) do |t|
              t.set_action("my_action")
              t.set_namespace("my_namespace")
              t.set_tags(:tag1 => "value1")
            end
          end

          it "applies the block to the error transaction when completed" do
            expect(transaction).not_to have_namespace("my_namespace")
            expect(transaction).not_to have_action("my_action")
            expect(transaction).not_to include_tags("tag1" => "value1")
            expect(transaction).to have_error
            expect(transaction).not_to be_completed

            transaction.complete
            expect(transaction).to have_namespace("my_namespace")
            expect(transaction).to have_action("my_action")
            expect(transaction).to include_tags("tag1" => "value1")
            expect(transaction).to have_error
            expect(transaction).to be_completed
          end

          it "does not apply the block to other error transactions" do
            Appsignal.report_error(StandardError.new("another error"))

            transaction.complete
            expect(created_transactions.count).to eq(2)

            expect(transaction).to have_namespace("my_namespace")
            expect(transaction).to have_action("my_action")
            expect(transaction).to include_tags("tag1" => "value1")
            expect(transaction).to have_error("ExampleException", "error message")
            expect(transaction).to be_completed

            expect(last_transaction).not_to be(transaction)
            expect(last_transaction).not_to have_namespace("my_namespace")
            expect(last_transaction).not_to have_action("my_action")
            expect(last_transaction).not_to include_tags("tag1" => "value1")
            expect(last_transaction).to have_error("StandardError", "another error")
            expect(last_transaction).to be_completed
          end

          it "does not create a new transaction" do
            expect(created_transactions).to eq([transaction])
          end

          it "yields and allows additional metadata to be set with the global helpers" do
            Appsignal.report_error(error) do
              Appsignal.set_action("my_action")
              Appsignal.set_namespace("my_namespace")
              Appsignal.set_tags(:tag1 => "value1")
            end

            expect(transaction).to_not be_completed

            transaction.complete
            expect(transaction).to have_namespace("my_namespace")
            expect(transaction).to have_action("my_action")
            expect(transaction).to have_error("ExampleException", "error message")
            expect(transaction).to include_tags("tag1" => "value1")
          end
        end
      end
    end

    describe ".set_action" do
      around { |example| keep_transactions { example.run } }

      context "with current transaction" do
        before { set_current_transaction(transaction) }

        it "sets the namespace on the current transaction" do
          Appsignal.set_action("custom")

          expect(transaction).to have_action("custom")
        end

        it "does not set the action if the action is nil" do
          Appsignal.set_action(nil)

          expect(transaction).to_not have_action
        end
      end

      context "without current transaction" do
        it "does not set ther action" do
          Appsignal.set_action("custom")

          expect(transaction).to_not have_action
        end
      end
    end

    describe ".set_namespace" do
      around { |example| keep_transactions { example.run } }

      context "with current transaction" do
        before { set_current_transaction(transaction) }

        it "should set the namespace to the current transaction" do
          Appsignal.set_namespace("custom")

          expect(transaction).to have_namespace("custom")
        end

        it "does not update the namespace if the namespace is nil" do
          Appsignal.set_namespace(nil)

          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        end
      end

      context "without current transaction" do
        it "does not update the namespace" do
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)

          Appsignal.set_namespace("custom")

          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        end
      end
    end

    describe ".instrument" do
      it_behaves_like "instrument helper" do
        let(:instrumenter) { Appsignal }
        before { set_current_transaction(transaction) }
      end
    end

    describe ".instrument_sql" do
      around { |example| keep_transactions { example.run } }
      before { set_current_transaction(transaction) }

      it "creates an SQL event on the transaction" do
        result =
          Appsignal.instrument_sql "name", "title", "body" do
            "return value"
          end

        expect(result).to eq "return value"
        expect(transaction).to include_event(
          "name" => "name",
          "title" => "title",
          "body" => "body",
          "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT
        )
      end
    end

    describe ".ignore_instrumentation_events" do
      around { |example| keep_transactions { example.run } }
      let(:transaction) { http_request_transaction }

      context "with current transaction" do
        before { set_current_transaction(transaction) }

        it "does not record events on the transaction" do
          expect(transaction).to receive(:pause!).and_call_original
          expect(transaction).to receive(:resume!).and_call_original

          Appsignal.instrument("register.this.event") { :do_nothing }
          Appsignal.ignore_instrumentation_events do
            Appsignal.instrument("dont.register.this.event") { :do_nothing }
          end

          expect(transaction).to include_event("name" => "register.this.event")
          expect(transaction).to_not include_event("name" => "dont.register.this.event")
        end
      end

      context "without current transaction" do
        let(:transaction) { nil }

        it "does not crash" do
          Appsignal.ignore_instrumentation_events { :do_nothing }
        end
      end
    end
  end

  describe "._start_logger" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:log_path) { File.join(tmp_dir, "log") }
    let(:log_file) { File.join(log_path, "appsignal.log") }
    let(:log_level) { "debug" }

    before do
      FileUtils.mkdir_p(log_path)
      # Clear state from previous test
      Appsignal.internal_logger = nil
      if Appsignal.instance_variable_defined?(:@in_memory_logger)
        Appsignal.remove_instance_variable(:@in_memory_logger)
      end
    end
    after { FileUtils.rm_rf(log_path) }

    def initialize_config
      Appsignal.configure(:production, :root_path => project_fixture_path) do |config|
        config.log_path = log_path
        config.log_level = log_level
      end
      Appsignal.internal_logger.error("Log in memory line 1")
      Appsignal.internal_logger.debug("Log in memory line 2")
      expect(Appsignal.in_memory_logger.messages).to_not be_empty
    end

    context "when the log path is writable" do
      context "when the log file is writable" do
        let(:log_file_contents) { File.read(log_file) }

        before do
          capture_stdout(out_stream) do
            initialize_config
            Appsignal._start_logger
            Appsignal.internal_logger.error("Log to file")
          end
          expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
        end

        it "logs to file" do
          expect(File.exist?(log_file)).to be_truthy
          expect(log_file_contents).to include "[ERROR] Log to file"
          expect(output).to be_empty
        end

        context "with log level info" do
          let(:log_level) { "info" }

          it "amends info log level and higher memory log messages to log file" do
            expect(log_file_contents).to include "[ERROR] appsignal: Log in memory line 1"
            expect(log_file_contents).to_not include "[DEBUG]"
          end
        end

        context "with log level debug" do
          let(:log_level) { "debug" }

          it "amends debug log level and higher memory log messages to log file" do
            expect(log_file_contents).to include "[ERROR] appsignal: Log in memory line 1"
            expect(log_file_contents).to include "[DEBUG] appsignal: Log in memory line 2"
          end
        end

        it "clears the in memory log after writing to the new logger" do
          expect(Appsignal.instance_variable_get(:@in_memory_logger)).to be_nil
        end
      end

      context "when the log file is not writable" do
        before do
          FileUtils.touch log_file
          FileUtils.chmod 0o444, log_file

          capture_stdout(out_stream) do
            initialize_config
            Appsignal._start_logger
            Appsignal.internal_logger.error("Log to not writable log file")
            expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
          end
        end

        it "logs to stdout" do
          expect(File.writable?(log_file)).to be_falsy
          expect(output).to include "[ERROR] appsignal: Log to not writable log file"
        end

        it "amends in memory log to stdout" do
          expect(output).to include "[ERROR] appsignal: Log in memory"
        end

        it "clears the in memory log after writing to the new logger" do
          expect(Appsignal.instance_variable_get(:@in_memory_logger)).to be_nil
        end

        it "outputs a warning" do
          expect(output).to include \
            "[WARN] appsignal: Unable to start internal logger with log path '#{log_file}'.",
            "[WARN] appsignal: Permission denied"
        end
      end
    end

    context "when the log path and fallback path are not writable" do
      before do
        FileUtils.chmod 0o444, log_path
        FileUtils.chmod 0o444, Appsignal::Config.system_tmp_dir

        capture_stdout(out_stream) do
          initialize_config
          Appsignal._start_logger
          Appsignal.internal_logger.error("Log to not writable log path")
        end
        expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
      end
      after do
        FileUtils.chmod 0o755, Appsignal::Config.system_tmp_dir
      end

      it "logs to stdout" do
        expect(File.writable?(log_path)).to be_falsy
        expect(output).to include "[ERROR] appsignal: Log to not writable log path"
      end

      it "amends in memory log to stdout" do
        expect(output).to include "[ERROR] appsignal: Log in memory"
      end

      it "outputs a warning" do
        expect(output).to include \
          "appsignal: Unable to log to '#{log_path}' " \
            "or the '#{Appsignal::Config.system_tmp_dir}' fallback."
      end
    end

    context "when on Heroku" do
      before do
        capture_stdout(out_stream) do
          initialize_config
          Appsignal._start_logger
          Appsignal.internal_logger.error("Log to stdout")
        end
        expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
      end
      around { |example| recognize_as_heroku { example.run } }

      it "logs to stdout" do
        expect(output).to include "[ERROR] appsignal: Log to stdout"
      end

      it "amends in memory log to stdout" do
        expect(output).to include "[ERROR] appsignal: Log in memory"
      end

      it "clears the in memory log after writing to the new logger" do
        expect(Appsignal.instance_variable_get(:@in_memory_logger)).to be_nil
      end
    end

    describe "#logger#level" do
      subject { Appsignal.internal_logger.level }

      context "when there is no config" do
        before do
          capture_stdout(out_stream) do
            Appsignal._start_logger
          end
        end

        it "sets the log level to info" do
          expect(subject).to eq Logger::INFO
        end
      end

      context "when there is a config" do
        context "when log level is configured to debug" do
          let(:log_level) { "debug" }
          before do
            capture_stdout(out_stream) do
              initialize_config
              Appsignal._start_logger
            end
          end

          it "sets the log level to debug" do
            expect(subject).to eq Logger::DEBUG
          end
        end
      end
    end
  end

  describe ".raise_if_not_started" do
    it "doesn't raise an error if AppSignal was started" do
      start_agent
      Appsignal.check_if_started!
    end

    it "raises an error if AppSignal was not started" do
      expect { Appsignal.check_if_started! }.to raise_error(Appsignal::NotStartedError) do |error|
        expect(error.cause).to be_nil
      end
    end

    it "raises the config error if the DSL file had an error" do
      test_path = File.join(tmp_dir, "config_file_test_6")
      FileUtils.mkdir_p(test_path)
      Dir.chdir test_path do
        config_contents =
          <<~CONFIG
            Appsignal.configure do |config|
              config.active = true
              config.name = "DSL app"
              config.push_api_key = "config_file_push_api_key"
            end
            raise "uh oh" # Deliberatly crash
          CONFIG
        write_file(File.join(test_path, "config", "appsignal.rb"), config_contents)
      end

      ENV["APPSIGNAL_APP_PATH"] = test_path
      silence(:allowed => ["Not starting AppSignal because an error occurred", "uh oh"]) do
        Appsignal.start
      end
      expect(Appsignal.config_error?).to be_truthy
      expect(Appsignal.config_error).to be_kind_of(RuntimeError)

      expect { Appsignal.check_if_started! }.to raise_error(Appsignal::NotStartedError) do |error|
        expect(error.cause).to be_kind_of(RuntimeError)
      end
    ensure
      FileUtils.rm_rf(test_path)
    end
  end
end
