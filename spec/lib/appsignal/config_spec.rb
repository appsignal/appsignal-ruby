describe Appsignal::Config do
  describe "#initialize" do
    subject { config.env }

    describe "environment" do
      context "when environment is nil" do
        let(:config) { described_class.new("", "") }

        it "sets an empty string" do
          expect(subject).to eq("")
        end
      end

      context "when environment is given" do
        let(:config) { described_class.new("", "my_env") }

        it "sets the environment" do
          expect(subject).to eq("my_env")
        end

        context "with APPSIGNAL_APP_ENV environment variable" do
          before { ENV["APPSIGNAL_APP_ENV"] = "my_env_env" }

          it "uses the environment variable" do
            expect(subject).to eq("my_env_env")
          end
        end
      end
    end
  end

  describe "config based on the system" do
    let(:config) { project_fixture_config(:none) }

    describe ":active" do
      subject { config[:active] }

      context "with APPSIGNAL_PUSH_API_KEY env variable" do
        before { ENV["APPSIGNAL_PUSH_API_KEY"] = "abc" }

        it "becomes active" do
          expect(subject).to be_truthy
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
      end

      context "when not running on Heroku" do
        it "is set to file" do
          expect(subject).to eq("file")
        end
      end
    end
  end

  describe "initial config" do
    let(:config) do
      described_class.new(
        "non-existing-path",
        "production",
        :push_api_key => "abc",
        :name => "TestApp",
        :active => true
      )
    end

    it "merges with the default config" do
      expect(config.config_hash).to eq(
        :debug                          => false,
        :log                            => "file",
        :ignore_errors                  => [],
        :ignore_actions                 => [],
        :filter_parameters              => [],
        :instrument_net_http            => true,
        :instrument_redis               => true,
        :instrument_sequel              => true,
        :skip_session_data              => false,
        :send_params                    => true,
        :endpoint                       => "https://push.appsignal.com",
        :push_api_key                   => "abc",
        :name                           => "TestApp",
        :active                         => true,
        :enable_frontend_error_catching => false,
        :frontend_error_catching_path   => "/appsignal_error_catcher",
        :enable_allocation_tracking     => true,
        :enable_gc_instrumentation      => false,
        :running_in_container           => false,
        :enable_host_metrics            => true,
        :enable_minutely_probes         => false,
        :hostname                       => Socket.gethostname,
        :ca_file_path                   => File.join(resources_dir, "cacert.pem")
      )
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
              :active => false
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

    it "is not valid or active" do
      expect(config.valid?).to be_truthy
      expect(config.active?).to be_truthy
    end

    it "does not log an error" do
      expect_any_instance_of(Logger).to_not receive(:error)
      config
    end

    describe "overriding system and defaults config" do
      let(:config) do
        described_class.new(
          "non-existing-path",
          "production",
          :running_in_container => true,
          :debug => true
        )
      end

      it "overrides system detected and defaults config" do
        expect(config[:running_in_container]).to be_truthy
        expect(config[:debug]).to be_truthy
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

      it "is not valid or active" do
        expect(config.valid?).to be_falsy
        expect(config.active?).to be_falsy
      end

      it "logs an error" do
        expect_any_instance_of(Logger).to receive(:error).once
          .with("Not loading from config file: config for 'nonsense' not found")
        expect_any_instance_of(Logger).to receive(:error).once
          .with("Push api key not set after loading config")
        config
      end
    end

    describe "old-style config keys" do
      describe ":api_key" do
        subject { config[:push_api_key] }

        context "without :push_api_key" do
          let(:config) { project_fixture_config("old_config") }

          it "sets the :push_api_key with the old :api_key value" do
            expect(subject).to eq "def"
          end
        end

        context "with :push_api_key" do
          let(:config) { project_fixture_config("old_config_mixed_with_new_config") }

          it "ignores the :api_key config" do
            expect(subject).to eq "ghi"
          end
        end
      end

      describe ":ignore_exceptions" do
        subject { config[:ignore_errors] }

        context "without :ignore_errors" do
          let(:config) { project_fixture_config("old_config") }

          it "sets :ignore_errors with the old :ignore_exceptions value" do
            expect(subject).to eq ["StandardError"]
          end
        end

        context "with :ignore_errors" do
          let(:config) { project_fixture_config("old_config_mixed_with_new_config") }

          it "ignores the :ignore_exceptions config" do
            expect(subject).to eq ["NoMethodError"]
          end
        end
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
    before do
      ENV["APPSIGNAL_RUNNING_IN_CONTAINER"] = "true"
      ENV["APPSIGNAL_PUSH_API_KEY"]         = "aaa-bbb-ccc"
      ENV["APPSIGNAL_ACTIVE"]               = "true"
      ENV["APPSIGNAL_APP_NAME"]             = "App name"
      ENV["APPSIGNAL_DEBUG"]                = "true"
      ENV["APPSIGNAL_IGNORE_ACTIONS"]       = "action1,action2"
    end

    it "overrides config with environment values" do
      expect(config.valid?).to be_truthy
      expect(config.active?).to be_truthy

      expect(config[:running_in_container]).to be_truthy
      expect(config[:push_api_key]).to eq "aaa-bbb-ccc"
      expect(config[:active]).to be_truthy
      expect(config[:name]).to eq "App name"
      expect(config[:debug]).to be_truthy
      expect(config[:ignore_actions]).to eq ["action1", "action2"]
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
  end

  describe "#[]" do
    let(:config) { project_fixture_config(:none, :push_api_key => "foo") }

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
      config[:http_proxy] = "http://localhost"
      config[:ignore_actions] = ["action1", "action2"]
      config[:ignore_errors] = ["VerySpecificError", "AnotherError"]
      config[:log_path] = "/tmp"
      config[:hostname] = "app1.local"
      config[:filter_parameters] = %w(password confirm_password)
      config[:running_in_container] = false
      config.write_to_environment
    end

    it "writes the current config to environment variables" do
      expect(ENV["APPSIGNAL_ACTIVE"]).to                       eq "true"
      expect(ENV["APPSIGNAL_APP_PATH"]).to                     end_with("spec/support/project_fixture")
      expect(ENV["APPSIGNAL_AGENT_PATH"]).to                   end_with("/ext")
      expect(ENV["APPSIGNAL_DEBUG_LOGGING"]).to                eq "false"
      expect(ENV["APPSIGNAL_LOG_FILE_PATH"]).to                end_with("/tmp/appsignal.log")
      expect(ENV["APPSIGNAL_PUSH_API_ENDPOINT"]).to            eq "https://push.appsignal.com"
      expect(ENV["APPSIGNAL_PUSH_API_KEY"]).to                 eq "abc"
      expect(ENV["APPSIGNAL_APP_NAME"]).to                     eq "TestApp"
      expect(ENV["APPSIGNAL_ENVIRONMENT"]).to                  eq "production"
      expect(ENV["APPSIGNAL_AGENT_VERSION"]).to                eq Appsignal::Extension.agent_version
      expect(ENV["APPSIGNAL_LANGUAGE_INTEGRATION_VERSION"]).to eq "ruby-#{Appsignal::VERSION}"
      expect(ENV["APPSIGNAL_HTTP_PROXY"]).to                   eq "http://localhost"
      expect(ENV["APPSIGNAL_IGNORE_ACTIONS"]).to               eq "action1,action2"
      expect(ENV["APPSIGNAL_IGNORE_ERRORS"]).to                eq "VerySpecificError,AnotherError"
      expect(ENV["APPSIGNAL_FILTER_PARAMETERS"]).to            eq "password,confirm_password"
      expect(ENV["APPSIGNAL_SEND_PARAMS"]).to                  eq "true"
      expect(ENV["APPSIGNAL_RUNNING_IN_CONTAINER"]).to         eq "false"
      expect(ENV["APPSIGNAL_ENABLE_HOST_METRICS"]).to          eq "true"
      expect(ENV["APPSIGNAL_ENABLE_MINUTELY_PROBES"]).to       eq "false"
      expect(ENV["APPSIGNAL_HOSTNAME"]).to                     eq "app1.local"
      expect(ENV["APPSIGNAL_PROCESS_NAME"]).to                 include "rspec"
      expect(ENV["APPSIGNAL_CA_FILE_PATH"]).to                 eq File.join(resources_dir, "cacert.pem")
      expect(ENV).to_not                                       have_key("APPSIGNAL_WORKING_DIR_PATH")
    end

    context "with :working_dir_path" do
      before do
        config[:working_dir_path] = "/tmp/appsignal2"
        config.write_to_environment
      end

      it "sets the modified :working_dir_path" do
        expect(ENV["APPSIGNAL_WORKING_DIR_PATH"]).to eq "/tmp/appsignal2"
      end
    end
  end

  describe "#log_file_path" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:config) { project_fixture_config("production", :log_path => log_path) }
    subject { capture_stdout(out_stream) { config.log_file_path } }

    context "when path is writable" do
      let(:log_path) { File.join(tmp_dir, "writable-path") }
      before { FileUtils.mkdir_p(log_path, :mode => 0755) }
      after { FileUtils.rm_rf(log_path) }

      it "returns log file path" do
        expect(subject).to eq File.join(log_path, "appsignal.log")
      end

      it "prints no warning" do
        subject
        expect(output).to be_empty
      end
    end

    shared_examples "#log_file_path: tmp path" do
      let(:system_tmp_dir) { described_class::SYSTEM_TMP_DIR }
      before { FileUtils.mkdir_p(system_tmp_dir) }
      after { FileUtils.rm_rf(system_tmp_dir) }

      context "when the /tmp fallback path is writable" do
        before { FileUtils.chmod(0777, system_tmp_dir) }

        it "returns returns the tmp location" do
          expect(subject).to eq(File.join(system_tmp_dir, "appsignal.log"))
        end

        it "prints a warning" do
          subject
          expect(output).to include "appsignal: Unable to log to '#{log_path}'. "\
            "Logging to '#{system_tmp_dir}' instead."
        end
      end

      context "when the /tmp fallback path is not writable" do
        before { FileUtils.chmod(0555, system_tmp_dir) }

        it "returns nil" do
          expect(subject).to be_nil
        end

        it "prints a warning" do
          subject
          expect(output).to include "appsignal: Unable to log to '#{log_path}' "\
            "or the '#{system_tmp_dir}' fallback."
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
          expect(subject).to eq File.join(config.root_path, "log/appsignal.log")
        end

        it "prints no warning" do
          subject
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
      before { FileUtils.mkdir_p(log_path, :mode => 0555) }
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
            FileUtils.chmod(0444, real_path)
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
            expect(subject).to eq(File.join(real_path, "appsignal.log"))
          end
        end
      end
    end
  end
end
