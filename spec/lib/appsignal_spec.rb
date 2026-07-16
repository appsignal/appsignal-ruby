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
        err_output = err_stream.read
        expect(err_output).to include("appsignal WARNING: #{message}")
        expect(err_output).to include("Called from:")
        expect(err_output).to match(/Called from:.*appsignal_spec\.rb:\d+/)
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
        err_output = err_stream.read
        expect(err_output).to include("appsignal WARNING: #{message}")
        expect(err_output).to include("Called from:")
        expect(err_output).to match(/Called from:.*appsignal_spec\.rb:\d+/)
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
        err_output = err_stream.read
        expect(err_output).to include("appsignal WARNING: #{message}")
        expect(err_output).to include("Called from:")
        expect(err_output).to match(/Called from:.*appsignal_spec\.rb:\d+/)
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

    if DependencyHelper.opentelemetry_present?
      context "when collector_endpoint is set but the OpenTelemetry SDK fails to boot" do
        let(:err_stream) { std_stream }
        let(:stdout_stream) { std_stream }

        before do
          # Simulate a failure inside `Appsignal::OpenTelemetry.configure` —
          # e.g. one of the OTel gems can't be loaded. The rescue inside
          # `configure` should set `started?` to false instead of letting the
          # error bubble out.
          allow(Appsignal::OpenTelemetry).to receive(:require)
            .with("opentelemetry/sdk")
            .and_raise(LoadError, "fake load failure")
        end

        it "falls back to the agent backend rather than silently dropping telemetry" do
          capture_std_streams(stdout_stream, err_stream) do
            start_agent(:options => { :collector_endpoint => "http://127.0.0.1:9090" })
          end

          # Config still records the user's intent.
          expect(Appsignal.config.collector_mode_configured?).to be(true)
          # But the active predicate is false because the SDK never booted.
          expect(Appsignal.config.collector_mode?).to be(false)
          expect(Appsignal::OpenTelemetry.started?).to be(false)

          # Backends fall through to the extension implementations.
          expect(Appsignal::Backends.metrics).to eq(Appsignal::Metrics::ExtensionBackend)
          expect(Appsignal::Backends.logger).to eq(Appsignal::Logger::ExtensionBackend)
        end
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

      it "starts the logger before restarting the extension" do
        expect(Appsignal).to receive(:_start_logger).ordered
        expect(Appsignal::Extension).to receive(:start).ordered

        expect(Appsignal.forked).to be_nil
      end

      it "does not stop the extension before restarting it" do
        allow(Appsignal).to receive(:_start_logger)
        allow(Appsignal::Extension).to receive(:start)
        expect(Appsignal::Extension).to_not receive(:stop)

        Appsignal.forked
      end

      it "does not restart minutely probes (probe thread dies on fork by design)" do
        allow(Appsignal).to receive(:_start_logger)
        allow(Appsignal::Extension).to receive(:start)
        expect(Appsignal::Probes).to_not receive(:start)

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

    if DependencyHelper.opentelemetry_present?
      context "in collector mode" do
        before do
          Appsignal.clear!
          start_agent(:options => { :collector_endpoint => "http://127.0.0.1:9090" })
        end

        it "shuts down the OpenTelemetry providers so buffered telemetry flushes" do
          expect(::OpenTelemetry.tracer_provider).to receive(:shutdown)
          expect(::OpenTelemetry.meter_provider).to receive(:shutdown)
          expect(::OpenTelemetry.logger_provider).to receive(:shutdown)
          Appsignal.stop
        end
      end
    end

    context "when not in collector mode" do
      it "calls Appsignal::OpenTelemetry.shutdown, which short-circuits as a no-op" do
        # `configure` was not called in this spec, so `started?` is false
        # and `shutdown` returns immediately without touching the API gem's
        # proxy providers (whose `shutdown` isn't defined until an SDK is
        # wired up).
        expect(Appsignal::OpenTelemetry.started?).to be(false)
        expect { Appsignal.stop }.not_to raise_error
      end
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
    # Only auto-start for non-mode examples. Mode-tagged examples
    # (`:agent_mode`/`:collector_mode`) start the agent in their own body (the
    # dual-mode start principle), so starting it here too would clobber the
    # collector-mode setup.
    before do |example|
      start_agent unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
    end
    around { |example| keep_transactions { example.run } }

    describe ".monitor" do
      describe "creating a transaction" do
        def perform
          Appsignal.monitor(:action => "MyAction")
        end

        it "in agent mode", :agent_mode do
          start_agent
          expect { perform }.to(change { created_transactions.count }.by(1))

          transaction = last_transaction
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(transaction).to have_action("MyAction")
          expect(transaction).to_not have_error
          expect(transaction).to_not include_events
          expect(transaction).to_not have_queue_start
          expect(transaction).to be_completed
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          expect { perform }.to(change { created_transactions.count }.by(1))

          # HTTP_REQUEST maps to a SERVER span (a subtrace root).
          expect(root_span.kind).to eq(:server)
          expect(root_span.attributes["appsignal.namespace"])
            .to eq("web")
          expect(root_span.name).to eq("MyAction")
          expect(root_span.attributes["appsignal.action_name"]).to eq("MyAction")
          expect(exception_events).to be_empty
          expect(event_spans).to be_empty
          expect(last_transaction).to be_completed
        end
      end

      it_in_both_modes "returns the block's return value" do
        expect(Appsignal.monitor(:action => nil) { :return_value }).to eq(:return_value)
      end

      describe "setting a custom namespace via the namespace argument" do
        def perform
          Appsignal.monitor(:namespace => "custom", :action => nil)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_namespace("custom")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.attributes["appsignal.namespace"]).to eq("custom")
        end
      end

      describe "not overwriting a custom namespace set in the block" do
        def perform
          Appsignal.monitor(:namespace => "custom", :action => nil) do
            Appsignal.set_namespace("more custom")
          end
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_namespace("more custom")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.attributes["appsignal.namespace"]).to eq("more custom")
        end
      end

      describe "setting the action via the action argument" do
        def perform(action)
          Appsignal.monitor(:action => action)
        end

        it "in agent mode using a string", :agent_mode do
          start_agent
          perform("custom")

          expect(last_transaction).to have_action("custom")
        end

        it "in collector mode using a string", :collector_mode do
          start_collector_agent
          perform("custom")

          expect(root_span.name).to eq("custom")
          expect(root_span.attributes["appsignal.action_name"]).to eq("custom")
        end

        it "in agent mode using a symbol", :agent_mode do
          start_agent
          perform(:custom)

          expect(last_transaction).to have_action("custom")
        end

        it "in collector mode using a symbol", :collector_mode do
          start_collector_agent
          perform(:custom)

          expect(root_span.name).to eq("custom")
          expect(root_span.attributes["appsignal.action_name"]).to eq("custom")
        end
      end

      describe "not overwriting a custom action set in the block" do
        def perform
          Appsignal.monitor(:action => "custom") do
            Appsignal.set_action("more custom")
          end
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_action("more custom")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.name).to eq("more custom")
          expect(root_span.attributes["appsignal.action_name"]).to eq("more custom")
        end
      end

      describe "not setting the action when the value is nil" do
        def perform
          Appsignal.monitor(:action => nil)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to_not have_action
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.attributes).to_not have_key("appsignal.action_name")
        end
      end

      describe "not setting the action when the value is :set_later" do
        def perform
          Appsignal.monitor(:action => :set_later)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to_not have_action
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.attributes).to_not have_key("appsignal.action_name")
        end
      end

      describe "reporting exceptions that occur in the block" do
        def perform
          expect do
            Appsignal.monitor :action => nil do
              raise ExampleException, "error message"
            end
          end.to raise_error(ExampleException, "error message")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_error("ExampleException", "error message")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.type"]).to eq("ExampleException")
          expect(event.attributes["exception.message"]).to eq("error message")
          expect(event.attributes["exception.stacktrace"]).to be_a(String)
          expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
          expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        end
      end

      context "with an already active transaction" do
        let(:err_stream) { std_stream }
        let(:stderr) { err_stream.read }
        let(:transaction) { http_request_transaction }

        # The parent transaction is built lazily inside each example body (after
        # the mode context has started the agent), per the dual-mode start
        # principle -- building it in a `before` would create it against the
        # wrong backend.
        def activate_parent_transaction
          set_current_transaction(transaction)
          transaction.set_action("My action")
        end

        it_in_both_modes "doesn't create a new transaction" do
          activate_parent_transaction
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

        describe "not overwriting the parent transaction's namespace" do
          def perform
            activate_parent_transaction
            silence { Appsignal.monitor(:namespace => "custom", :action => nil) }
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(root_span.attributes["appsignal.namespace"])
              .to eq("web")
          end
        end

        describe "not overwriting the parent transaction's action" do
          def perform
            activate_parent_transaction
            silence { Appsignal.monitor(:action => "custom") }
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(transaction).to have_action("My action")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(root_span.name).to eq("My action")
            expect(root_span.attributes["appsignal.action_name"]).to eq("My action")
          end
        end

        it_in_both_modes "doesn't complete the parent transaction" do
          activate_parent_transaction
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
      before do |example|
        start_agent unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }

        describe "setting tags on the current transaction" do
          def perform
            set_current_transaction(transaction)
            Appsignal.tag_request("a" => "b")
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction._sample
            expect(transaction).to include_tags("a" => "b")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(root_span.attributes["appsignal.tag.a"]).to eq("b")
          end
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
      before do |example|
        start_agent unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
      end

      it "has a .set_params alias" do
        expect(Appsignal.method(:add_params)).to eq(Appsignal.method(:set_params))
      end

      describe "adding parameters through the public API" do
        let(:transaction) { http_request_transaction }

        def perform
          set_current_transaction(transaction)
          Appsignal.add_params("param1" => "value1")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          transaction._sample
          expect(transaction).to include_params("param1" => "value1")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
            .to eq("param1" => "value1")
        end
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }

        describe "merging the params if called multiple times" do
          def perform
            set_current_transaction(transaction)
            Appsignal.add_params("param1" => "value1")
            Appsignal.add_params("param2" => "value2")
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction._sample
            expect(transaction).to include_params(
              "param1" => "value1",
              "param2" => "value2"
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
              .to eq("param1" => "value1", "param2" => "value2")
          end
        end

        describe "adding parameters with a block" do
          def perform
            set_current_transaction(transaction)
            Appsignal.add_params { { "param1" => "value1" } }
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction._sample
            expect(transaction).to include_params("param1" => "value1")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
              .to eq("param1" => "value1")
          end
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
      describe "marking parameters to be sent as an empty value" do
        let(:transaction) { http_request_transaction }

        def perform
          set_current_transaction(transaction)
          Appsignal.add_params("key1" => "value")
          Appsignal.set_empty_params!
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          transaction._sample
          expect(transaction).to_not include_params
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes).to_not have_key("appsignal.request.payload")
        end
      end
    end

    describe ".add_session_data" do
      before do |example|
        start_agent unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
      end

      it "has a .set_session_data alias" do
        expect(Appsignal.method(:add_session_data)).to eq(Appsignal.method(:set_session_data))
      end

      describe "adding session data through the public API" do
        let(:transaction) { http_request_transaction }

        def perform
          set_current_transaction(transaction)
          Appsignal.add_session_data("data" => "value1")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          transaction._sample
          expect(transaction).to include_session_data("data" => "value1")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
            .to eq("data" => "value1")
        end
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }

        describe "merging the session data if called multiple times" do
          def perform
            set_current_transaction(transaction)
            Appsignal.set_session_data("data1" => "value1")
            Appsignal.set_session_data("data2" => "value2")
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction._sample
            expect(transaction).to include_session_data(
              "data1" => "value1",
              "data2" => "value2"
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
              .to eq("data1" => "value1", "data2" => "value2")
          end
        end

        describe "adding session data with a block" do
          def perform
            set_current_transaction(transaction)
            Appsignal.set_session_data { { "data" => "value1" } }
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction._sample
            expect(transaction).to include_session_data("data" => "value1")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
              .to eq("data" => "value1")
          end
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
      before do |example|
        start_agent unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
      end

      it "has a .set_headers alias" do
        expect(Appsignal.method(:add_headers)).to eq(Appsignal.method(:set_headers))
      end

      describe "adding request headers through the public API" do
        let(:transaction) { http_request_transaction }

        def perform
          set_current_transaction(transaction)
          Appsignal.add_headers("HTTP_ACCEPT" => "text/html")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          transaction._sample
          expect(transaction).to include_environment("HTTP_ACCEPT" => "text/html")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          # True headers are normalized to the OTel http.request.header.* convention.
          expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
        end
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }

        # Uses true HTTP headers (rather than CGI vars like PATH_INFO) because
        # collector mode only emits the HTTP_*/CONTENT_* headers as
        # http.request.header.* attributes and drops the rest.
        describe "merging the request headers if called multiple times" do
          def perform
            set_current_transaction(transaction)
            Appsignal.add_headers("HTTP_ACCEPT" => "text/html")
            Appsignal.add_headers("HTTP_ACCEPT_CHARSET" => "utf-8")
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction._sample
            expect(transaction).to include_environment(
              "HTTP_ACCEPT" => "text/html",
              "HTTP_ACCEPT_CHARSET" => "utf-8"
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
            expect(root_span.attributes["http.request.header.accept-charset"]).to eq("utf-8")
          end
        end

        describe "adding request headers with a block" do
          def perform
            set_current_transaction(transaction)
            Appsignal.add_headers { { "HTTP_ACCEPT" => "text/html" } }
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction._sample
            expect(transaction).to include_environment("HTTP_ACCEPT" => "text/html")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
          end
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
      before do |example|
        start_agent unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
      end

      it "has a .set_custom_data alias" do
        expect(Appsignal.method(:add_custom_data)).to eq(Appsignal.method(:set_custom_data))
      end

      describe "adding custom data through the public API" do
        let(:transaction) { http_request_transaction }

        def perform
          set_current_transaction(transaction)
          Appsignal.add_custom_data(
            :user => { :id => 123 },
            :organization => { :slug => "appsignal" }
          )
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          transaction._sample
          expect(transaction).to include_custom_data(
            "user" => { "id" => 123 },
            "organization" => { "slug" => "appsignal" }
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.custom_data"])).to eq(
            "user" => { "id" => 123 },
            "organization" => { "slug" => "appsignal" }
          )
        end
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }

        describe "merging the custom data if called multiple times" do
          def perform
            set_current_transaction(transaction)
            Appsignal.add_custom_data(:abc => "value")
            Appsignal.add_custom_data(:def => "value")
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction._sample
            expect(transaction).to include_custom_data(
              "abc" => "value",
              "def" => "value"
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(JSON.parse(root_span.attributes["appsignal.custom_data"]))
              .to eq("abc" => "value", "def" => "value")
          end
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
      before do |example|
        start_agent unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
      end

      describe "adding a breadcrumb through the public API" do
        let(:transaction) { http_request_transaction }

        def perform
          set_current_transaction(transaction)
          Appsignal.add_breadcrumb(
            "Network",
            "http",
            "User made network request",
            { :response => 200 },
            fixed_time
          )
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          transaction.complete
          expect(transaction).to include_breadcrumb(
            "http",
            "Network",
            "User made network request",
            { "response" => 200 },
            fixed_time
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          # Breadcrumbs are emitted as `appsignal.breadcrumb` span events.
          breadcrumb = root_span.events.find { |e| e.name == "appsignal.breadcrumb" }
          expect(breadcrumb).not_to be_nil
          expect(breadcrumb.attributes["category"]).to eq("Network")
          expect(breadcrumb.attributes["action"]).to eq("http")
          expect(breadcrumb.attributes["message"]).to eq("User made network request")
          expect(JSON.parse(breadcrumb.attributes["metadata"])).to eq("response" => 200)
        end
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "does not add a breadcrumb to any transaction" do
          expect(Appsignal.add_breadcrumb("Network", "http")).to be_falsy
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

      describe "sending the error" do
        def perform
          Appsignal.send_error(error)
        end

        it "in agent mode", :agent_mode do
          start_agent
          expect { perform }.to(change { created_transactions.count }.by(1))

          transaction = last_transaction
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(transaction).to_not have_action
          expect(transaction).to have_error("ExampleException", "error message")
          expect(transaction).to_not include_tags
          expect(transaction).to be_completed
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          # send_error completes its throwaway transaction inline, so the root
          # span is already finished and exported.
          perform

          expect(root_span).not_to be_nil
          # HTTP_REQUEST maps to a SERVER span (a subtrace root).
          expect(root_span.kind).to eq(:server)
          expect(root_span.attributes["appsignal.namespace"])
            .to eq("web")
          expect(root_span.attributes).not_to have_key("appsignal.action_name")

          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.type"]).to eq("ExampleException")
          expect(event.attributes["exception.message"]).to eq("error message")
          expect(event.attributes["exception.stacktrace"]).to be_a(String)
          expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
          expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        end
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
        describe "yielding the transaction to set metadata" do
          def perform
            Appsignal.send_error(StandardError.new("my_error")) do |transaction|
              transaction.set_action("my_action")
              transaction.set_namespace("my_namespace")
            end
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(last_transaction).to have_namespace("my_namespace")
            expect(last_transaction).to have_action("my_action")
            expect(last_transaction).to have_error("StandardError", "my_error")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(root_span.name).to eq("my_action")
            expect(root_span.attributes["appsignal.action_name"]).to eq("my_action")
            expect(root_span.attributes["appsignal.namespace"]).to eq("my_namespace")

            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("StandardError")
            expect(event.attributes["exception.message"]).to eq("my_error")
            expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
            expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
          end
        end

        it "logs a raising block without raising, naming the helper" do
          logs = capture_logs do
            expect do
              Appsignal.send_error(StandardError.new("my_error")) do
                raise ExampleStandardError, "metadata boom"
              end
            end.to_not raise_error
          end

          expect(logs).to contains_log(
            :error,
            /Error in the block passed to Appsignal\.send_error, defined at .+metadata boom/
          )
        end

        # The block uses the global helpers, which act on the current
        # transaction. send_error runs the block against its own transaction, so
        # the block's metadata and the error must land there, not on the
        # transaction that was active when send_error was called. That active
        # transaction must be restored afterwards and left untouched.
        describe "yielding to set metadata with global helpers, " \
          "with an active transaction" do
          def perform
            active_transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
            active_transaction.set_action("active action")
            active_transaction.set_namespace("active namespace")

            Appsignal.send_error(StandardError.new("my_error")) do
              Appsignal.set_action("my_action")
              Appsignal.set_namespace("my_namespace")
              Appsignal.add_tags(:block_tag => "value")
            end

            active_transaction
          end

          it "in agent mode", :agent_mode do
            start_agent
            active_transaction = perform

            # The active transaction is restored as the current transaction.
            expect(current_transaction).to eq(active_transaction)

            # The block ran against send_error's own transaction.
            expect(last_transaction).to have_namespace("my_namespace")
            expect(last_transaction).to have_action("my_action")
            expect(last_transaction).to include_tags("block_tag" => "value")
            expect(last_transaction).to have_error("StandardError", "my_error")
            expect(last_transaction).to be_completed

            # The active transaction is untouched.
            expect(active_transaction).to have_namespace("active namespace")
            expect(active_transaction).to have_action("active action")
            expect(active_transaction).to_not include_tags
            expect(active_transaction).to_not be_completed
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            active_transaction = perform

            # send_error restores the active transaction as both the current
            # AppSignal transaction and the current OpenTelemetry span, so the
            # active trace continues rather than being dropped or left open.
            expect(current_transaction).to eq(active_transaction)
            active_trace_id = ::OpenTelemetry::Trace.current_span.context.trace_id

            # Finish the active transaction so its root span is exported too.
            Appsignal::Transaction.complete_current!

            server_spans = span_exporter.finished_spans.select { |s| s.kind == :server }
            error_span = server_spans.find { |s| s.name == "my_action" }
            active_span = server_spans.find { |s| s.name == "active action" }
            expect(error_span).not_to be_nil
            expect(active_span).not_to be_nil

            # send_error reports on its own transaction, a separate trace from
            # the active one, which continues on the trace that stayed current.
            expect(active_span.trace_id).to eq(active_trace_id)
            expect(error_span.trace_id).not_to eq(active_trace_id)

            # The block's metadata and the error land on send_error's trace.
            expect(error_span.attributes["appsignal.namespace"]).to eq("my_namespace")
            expect(error_span.attributes["appsignal.tag.block_tag"]).to eq("value")
            expect(Array(error_span.events).map(&:name)).to include("exception")

            # The active trace is untouched: no block metadata, no error.
            expect(active_span.attributes["appsignal.namespace"]).to eq("active namespace")
            expect(active_span.attributes).to_not have_key("appsignal.tag.block_tag")
            expect(Array(active_span.events).map(&:name)).to_not include("exception")
          end
        end
      end
    end

    describe ".set_error" do
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      let(:error) { ExampleException.new("I am an exception") }
      let(:transaction) { http_request_transaction }
      around { |example| keep_transactions { example.run } }

      describe "adding the error to the active transaction" do
        # `set_current_transaction` (which builds the transaction's root span)
        # happens in the body, not a `before`, so in collector mode it uses the
        # in-memory provider that `start_collector_agent` swaps in.
        def perform
          set_current_transaction(transaction)
          Appsignal.set_error(error)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          transaction._sample
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(transaction).to have_error("ExampleException", "I am an exception")
          expect(transaction).to_not include_tags
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.type"]).to eq("ExampleException")
          expect(event.attributes["exception.message"]).to eq("I am an exception")
          expect(event.attributes["exception.stacktrace"]).to be_a(String)
          expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
          expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        end
      end

      context "when there is an active transaction" do
        # Mode-tagged examples set the current transaction in their own body,
        # after starting the agent, so collector mode builds the root span
        # against the in-memory provider. Untagged examples keep the hook.
        before do |example|
          unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
            set_current_transaction(transaction)
          end
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

        describe "when given a block" do
          # The set_error helper yields the current transaction and runs the
          # block synchronously, so the block's metadata lands on the active
          # transaction in both modes.
          def perform
            set_current_transaction(transaction)
            Appsignal.set_error(StandardError.new("my_error")) do |t|
              t.set_action("my_action")
              t.set_namespace("my_namespace")
            end
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(transaction).to have_namespace("my_namespace")
            expect(transaction).to have_action("my_action")
            expect(transaction).to have_error("StandardError", "my_error")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            expect(root_span.name).to eq("my_action")
            expect(root_span.attributes["appsignal.action_name"]).to eq("my_action")
            expect(root_span.attributes["appsignal.namespace"]).to eq("my_namespace")

            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("StandardError")
            expect(event.attributes["exception.message"]).to eq("my_error")
            expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
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
        describe "reporting the error" do
          def perform
            Appsignal.report_error(error)
          end

          it "in agent mode", :agent_mode do
            start_agent
            expect { perform }.to(change { created_transactions.count }.by(1))

            expect(last_transaction).to have_error("ExampleException", "error message")
            expect(last_transaction).to be_completed
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            # With no active transaction, report_error creates and completes its
            # own transaction, so the root span is exported.
            perform

            expect(root_span).not_to be_nil
            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("ExampleException")
            expect(event.attributes["exception.message"]).to eq("error message")
            expect(event.attributes["exception.stacktrace"]).to be_a(String)
            expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
            expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
          end
        end

        context "when given a block" do
          # With no active transaction, report_error creates its own
          # transaction and completes it, so the block's metadata and the error
          # land on that transaction in both modes.
          shared_examples "reports the metadata on its own transaction" do
            it "in agent mode", :agent_mode do
              start_agent
              perform

              transaction = last_transaction
              expect(transaction).to have_namespace("my_namespace")
              expect(transaction).to have_action("my_action")
              expect(transaction).to have_error("ExampleException", "error message")
              expect(transaction).to include_tags("tag1" => "value1")
              expect(transaction).to be_completed
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(root_span.name).to eq("my_action")
              expect(root_span.attributes["appsignal.action_name"]).to eq("my_action")
              expect(root_span.attributes["appsignal.namespace"]).to eq("my_namespace")
              expect(root_span.attributes["appsignal.tag.tag1"]).to eq("value1")

              event = root_span.events.find { |e| e.name == "exception" }
              expect(event).not_to be_nil
              expect(event.attributes["exception.type"]).to eq("ExampleException")
              expect(event.attributes["exception.message"]).to eq("error message")
              expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
            end
          end

          describe "yielding the transaction" do
            def perform
              Appsignal.report_error(error) do |t|
                t.set_action("my_action")
                t.set_namespace("my_namespace")
                t.set_tags(:tag1 => "value1")
              end
            end

            include_examples "reports the metadata on its own transaction"
          end

          describe "with the global helpers" do
            def perform
              Appsignal.report_error(error) do
                Appsignal.set_action("my_action")
                Appsignal.set_namespace("my_namespace")
                Appsignal.set_tags(:tag1 => "value1")
              end
            end

            include_examples "reports the metadata on its own transaction"
          end

          it "logs a raising block without raising, naming the helper" do
            logs = capture_logs do
              expect do
                Appsignal.report_error(error) do
                  raise ExampleStandardError, "metadata boom"
                end
              end.to_not raise_error
            end

            expect(logs).to contains_log(
              :error,
              /Error in the block passed to Appsignal\.report_error, defined at .+metadata boom/
            )
          end
        end
      end

      context "when there is an active transaction" do
        let(:transaction) { http_request_transaction }
        # Only for non-mode examples. Mode-tagged examples set the current
        # transaction in their own body, after starting the agent (collector
        # mode swaps in the in-memory providers there).
        before do |example|
          unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
            set_current_transaction(transaction)
          end
        end

        describe "reporting the error onto it" do
          def perform
            set_current_transaction(transaction)
            Appsignal.report_error(error)
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(last_transaction).to eq(transaction)
            transaction._sample
            expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
            expect(transaction).to have_error("ExampleException", "error message")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("ExampleException")
            expect(event.attributes["exception.message"]).to eq("error message")
            expect(event.attributes["exception.stacktrace"]).to be_a(String)
            expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
            expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
          end
        end

        describe "with multiple reported errors" do
          let(:other_error) do
            ExampleStandardError.new("other message").tap { |e| e.set_backtrace(["line 2"]) }
          end

          def perform
            set_current_transaction(transaction)
            Appsignal.report_error(error)
            Appsignal.report_error(other_error)
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform
            # The extension holds one error per transaction, so the extra error
            # is reported as a duplicate transaction.
            expect { transaction.complete }.to(change { created_transactions.count }.by(1))

            expect(created_transactions.map { |t| t.to_h["error"]["message"] })
              .to contain_exactly("error message", "other message")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            transaction.complete

            # One trace: a single root span carrying one exception event per error.
            root_spans = span_exporter.finished_spans.select do |span|
              [:server, :consumer].include?(span.kind)
            end
            expect(root_spans.size).to eq(1)
            events = root_spans.first.events.select { |e| e.name == "exception" }
            expect(events.map { |e| e.attributes["exception.message"] })
              .to contain_exactly("error message", "other message")
          end
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

        it_in_both_modes "does not complete the transaction" do
          set_current_transaction(transaction)
          Appsignal.report_error(error)

          expect(transaction).to_not be_completed
        end

        context "when given a block" do
          # Agent mode defers the block to completion; the collector example
          # below starts the agent and reports the error itself, so it skips
          # this setup.
          before do |example|
            next if example.metadata[:collector_mode]

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

          it "applies the block to the transaction eagerly", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            Appsignal.report_error(error) do |t|
              t.set_action("my_action")
              t.set_namespace("my_namespace")
              t.set_tags(:tag1 => "value1")
            end

            # Collector mode records the error and runs its block when the error
            # is added, not at completion as agent mode does. So the action name
            # is on the active transaction's span right away. Tags flush with the
            # other sample data at completion.
            expect(::OpenTelemetry::Trace.current_span.name).to eq("my_action")

            transaction.complete
            expect(root_span.name).to eq("my_action")
            expect(root_span.attributes["appsignal.action_name"]).to eq("my_action")
            expect(root_span.attributes["appsignal.namespace"]).to eq("my_namespace")
            expect(root_span.attributes["appsignal.tag.tag1"]).to eq("value1")

            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.message"]).to eq("error message")
          end
        end
      end
    end

    describe ".set_action" do
      around { |example| keep_transactions { example.run } }

      describe "setting the action on the current transaction" do
        def perform
          set_current_transaction(transaction)
          Appsignal.set_action("custom")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(transaction).to have_action("custom")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.name).to eq("custom")
          expect(root_span.attributes["appsignal.action_name"]).to eq("custom")
        end
      end

      # The nil and no-current-transaction cases are guarded in the helper
      # before any backend, so they behave the same in both modes.
      context "with current transaction" do
        before { set_current_transaction(transaction) }

        it "does not set the action if the action is nil" do
          Appsignal.set_action(nil)

          expect(transaction).to_not have_action
        end
      end

      context "without current transaction" do
        it "does not set the action" do
          Appsignal.set_action("custom")

          expect(transaction).to_not have_action
        end
      end
    end

    describe ".set_namespace" do
      around { |example| keep_transactions { example.run } }

      describe "setting the namespace on the current transaction" do
        def perform
          set_current_transaction(transaction)
          Appsignal.set_namespace("custom")
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(transaction).to have_namespace("custom")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["appsignal.namespace"]).to eq("custom")
        end
      end

      # The nil and no-current-transaction cases are guarded in the helper
      # before any backend, so they behave the same in both modes.
      context "with current transaction" do
        before { set_current_transaction(transaction) }

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
  end

  describe "custom metrics" do
    let(:tags) { { :foo => "bar" } }

    describe ".set_gauge" do
      describe "with a string key and float value" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 0.1, Appsignal::Extension.data_map_new)
          Appsignal.set_gauge("key", 0.1)
        end
      end

      describe "with tags" do
        def perform
          Appsignal.set_gauge("key", 0.1, tags)
        end

        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 0.1, Appsignal::Utils::Data.generate(tags))
          perform
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          allow(Appsignal::Metrics::OpenTelemetryBackend).to receive(:set_gauge)
          expect(Appsignal::Extension).not_to receive(:set_gauge)
          perform
          expect(Appsignal::Metrics::OpenTelemetryBackend).to have_received(:set_gauge)
            .with("key", 0.1, tags)
        end
      end

      describe "with a symbol key and int value" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 1.0, Appsignal::Extension.data_map_new)
          Appsignal.set_gauge(:key, 1)
        end
      end

      describe "when the value is out of range" do
        it "in agent mode", :agent_mode do
          start_agent
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
    end

    describe ".increment_counter" do
      describe "with a string key" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 1, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter("key")
        end
      end

      describe "with tags" do
        def perform
          Appsignal.increment_counter("key", 5, tags)
        end

        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 5, Appsignal::Utils::Data.generate(tags))
          perform
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          allow(Appsignal::Metrics::OpenTelemetryBackend).to receive(:increment_counter)
          expect(Appsignal::Extension).not_to receive(:increment_counter)
          perform
          expect(Appsignal::Metrics::OpenTelemetryBackend).to have_received(:increment_counter)
            .with("key", 5, tags)
        end
      end

      describe "with a symbol key" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 1, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter(:key)
        end
      end

      describe "with a count" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 5, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter("key", 5)
        end
      end

      describe "when the value is out of range" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 10, Appsignal::Extension.data_map_new).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("The counter value '10' for metric 'key' is too big")

          Appsignal.increment_counter("key", 10)
        end
      end
    end

    describe ".add_distribution_value" do
      describe "with a string key and float value" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 0.1, Appsignal::Extension.data_map_new)
          Appsignal.add_distribution_value("key", 0.1)
        end
      end

      describe "with tags" do
        def perform
          Appsignal.add_distribution_value("key", 0.1, tags)
        end

        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 0.1, Appsignal::Utils::Data.generate(tags))
          perform
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          allow(Appsignal::Metrics::OpenTelemetryBackend).to receive(:add_distribution_value)
          expect(Appsignal::Extension).not_to receive(:add_distribution_value)
          perform
          expect(Appsignal::Metrics::OpenTelemetryBackend).to have_received(:add_distribution_value)
            .with("key", 0.1, tags)
        end
      end

      describe "with a symbol key and int value" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 1.0, Appsignal::Extension.data_map_new)
          Appsignal.add_distribution_value(:key, 1)
        end
      end

      describe "when the value is out of range" do
        it "in agent mode", :agent_mode do
          start_agent
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 10, Appsignal::Extension.data_map_new).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("The distribution value '10' for metric 'key' is too big")

          Appsignal.add_distribution_value("key", 10)
        end
      end
    end
  end

  describe ".instrument" do
    describe "block return value" do
      it_in_both_modes do
        set_current_transaction(transaction)

        result = Appsignal.instrument("name", "title", "body") { "return value" }

        expect(result).to eq("return value")
      end
    end

    describe "recording an event around the block" do
      def perform
        Appsignal.instrument("name", "title", "body") { :do_nothing }
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform
        expect(transaction).to include_event(
          "name" => "name",
          "title" => "title",
          "body" => "body",
          "body_format" => Appsignal::EventFormatter::DEFAULT
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("title")
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(span.attributes["appsignal.category"]).to eq("name")
        expect(span.attributes["appsignal.body"]).to eq("body")
        expect(span.attributes).not_to have_key("db.query.text")
        expect(span.attributes).not_to have_key("db.system.name")
      end
    end

    describe "when an error is raised in the block" do
      def perform
        expect do
          Appsignal.instrument("name", "title", "body") { raise ExampleException, "foo" }
        end.to raise_error(ExampleException, "foo")
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform
        expect(transaction).to include_event(
          "name" => "name", "title" => "title", "body" => "body"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("title")
        expect(span.attributes["appsignal.category"]).to eq("name")
        expect(span.attributes["appsignal.body"]).to eq("body")
      end
    end

    describe "when a symbol is thrown in the block" do
      def perform
        expect do
          Appsignal.instrument("name", "title", "body") { throw :foo }
        end.to throw_symbol(:foo)
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform
        expect(transaction).to include_event(
          "name" => "name", "title" => "title", "body" => "body"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("title")
        expect(span.attributes["appsignal.category"]).to eq("name")
        expect(span.attributes["appsignal.body"]).to eq("body")
      end
    end
  end

  describe ".instrument_sql" do
    describe "recording a SQL event around the block" do
      def perform
        Appsignal.instrument_sql("name", "title", "body") { "return value" }
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)

        expect(perform).to eq("return value")
        expect(transaction).to include_event(
          "name" => "name",
          "title" => "title",
          "body" => "body",
          "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)

        expect(perform).to eq("return value")
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("title")
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(span.attributes["appsignal.category"]).to eq("name")
        expect(span.attributes["db.query.text"]).to eq("body")
        expect(span.attributes["db.system.name"]).to eq("other_sql")
        expect(span.attributes).not_to have_key("appsignal.body")
      end
    end
  end

  describe ".ignore_instrumentation_events" do
    describe "with a current transaction" do
      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        expect(transaction).to receive(:pause!).and_call_original
        expect(transaction).to receive(:resume!).and_call_original

        Appsignal.instrument("register.this.event") { :do_nothing }
        Appsignal.ignore_instrumentation_events do
          Appsignal.instrument("dont.register.this.event") { :do_nothing }
        end

        expect(transaction).to include_event("name" => "register.this.event")
        expect(transaction).to_not include_event("name" => "dont.register.this.event")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)

        Appsignal.instrument("register.this.event") { :do_nothing }
        Appsignal.ignore_instrumentation_events do
          Appsignal.instrument("dont.register.this.event") { :do_nothing }
        end
        Appsignal::Transaction.complete_current!

        names = event_spans.map(&:name)
        expect(names).to include("register.this.event")
        expect(names).not_to include("dont.register.this.event")
      end
    end

    describe "without a current transaction" do
      it_in_both_modes do
        expect do
          Appsignal.ignore_instrumentation_events { :do_nothing }
        end.not_to raise_error
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
