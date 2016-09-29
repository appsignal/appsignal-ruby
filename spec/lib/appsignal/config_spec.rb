describe Appsignal::Config do
  subject { config }

  describe "with a config file" do
    let(:config) { project_fixture_config('production') }

    it "should not log an error" do
      Logger.any_instance.should_not_receive(:log_error)
      subject
    end

    its(:valid?)        { should be_true }
    its(:active?)       { should be_true }
    its(:log_file_path) { should end_with('spec/support/project_fixture/appsignal.log') }

    describe "default config" do
      around { |example| recognize_as_container(:none) { example.run } }

      it "merges with the defaults" do
        subject.config_hash.should eq({
          :debug                          => false,
          :ignore_errors                  => [],
          :ignore_actions                 => [],
          :filter_parameters              => [],
          :instrument_net_http            => true,
          :instrument_redis               => true,
          :instrument_sequel              => true,
          :skip_session_data              => false,
          :send_params                    => true,
          :endpoint                       => 'https://push.appsignal.com',
          :push_api_key                   => 'abc',
          :name                           => 'TestApp',
          :active                         => true,
          :enable_frontend_error_catching => false,
          :frontend_error_catching_path   => '/appsignal_error_catcher',
          :enable_allocation_tracking     => true,
          :enable_gc_instrumentation      => false,
          :running_in_container           => false,
          :enable_host_metrics            => true,
          :enable_minutely_probes         => false,
          :hostname                       => Socket.gethostname,
          :ca_file_path                   => File.join(resources_dir, 'cacert.pem')
        })
      end
    end

    describe "#log_file_path" do
      let(:stdout) { StringIO.new }
      let(:config) { project_fixture_config('production', :log_path => log_path) }
      subject { config.log_file_path }
      around do |example|
        original_stdout = $stdout
        $stdout = stdout
        example.run
        $stdout = original_stdout
      end

      context "when path is writable" do
        let(:log_path) { File.join(tmp_dir, 'writable-path') }
        before { FileUtils.mkdir_p(log_path, :mode => 0755) }
        after { FileUtils.rm_rf(log_path) }

        it "returns log file path" do
          expect(subject).to eq File.join(log_path, 'appsignal.log')
        end

        it "prints no warning" do
          subject
          expect(stdout.string).to be_empty
        end
      end

      shared_examples '#log_file_path: tmp path' do
        let(:system_tmp_dir) { Appsignal::Config::SYSTEM_TMP_DIR }
        before { FileUtils.mkdir_p(system_tmp_dir) }
        after { FileUtils.rm_rf(system_tmp_dir) }

        context "when the /tmp fallback path is writable" do
          before { FileUtils.chmod(0777, system_tmp_dir) }

          it "returns returns the tmp location" do
            expect(subject).to eq(File.join(system_tmp_dir, 'appsignal.log'))
          end

          it "prints a warning" do
            subject
            expect(stdout.string).to include "appsignal: Unable to log to '#{log_path}'. "\
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
            expect(stdout.string).to include "appsignal: Unable to log to '#{log_path}' "\
              "or the '#{system_tmp_dir}' fallback."
          end
        end
      end

      context "when path is nil" do
        let(:log_path) { nil }

        context "when root_path is nil" do
          before { allow(config).to receive(:root_path).and_return(nil) }

          include_examples '#log_file_path: tmp path'
        end

        context "when root_path is set" do
          it "returns returns the project log location" do
            expect(subject).to eq File.join(config.root_path, 'appsignal.log')
          end

          it "prints no warning" do
            subject
            expect(stdout.string).to be_empty
          end
        end
      end

      context "when path does not exist" do
        let(:log_path) { '/non-existing' }

        include_examples '#log_file_path: tmp path'
      end

      context "when path is not writable" do
        let(:log_path) { File.join(tmp_dir, 'not-writable-path') }
        before { FileUtils.mkdir_p(log_path, :mode => 0555) }
        after { FileUtils.rm_rf(log_path) }

        include_examples '#log_file_path: tmp path'
      end

      context "when path is a symlink" do
        context "when linked path does not exist" do
          let(:real_path) { File.join(tmp_dir, 'real-path') }
          let(:log_path) { File.join(tmp_dir, 'symlink-path') }
          before { File.symlink(real_path, log_path) }
          after { FileUtils.rm(log_path) }

          include_examples '#log_file_path: tmp path'
        end

        context "when linked path exists" do
          context "when linked path is not writable" do
            let(:real_path) { File.join(tmp_dir, 'real-path') }
            let(:log_path) { File.join(tmp_dir, 'symlink-path') }
            before do
              FileUtils.mkdir_p(real_path)
              FileUtils.chmod(0444, real_path)
              File.symlink(real_path, log_path)
            end
            after do
              FileUtils.rm_rf(real_path)
              FileUtils.rm(log_path)
            end

            include_examples '#log_file_path: tmp path'
          end

          context "when linked path is writable" do
            let(:real_path) { File.join(tmp_dir, 'real-path') }
            let(:log_path) { File.join(tmp_dir, 'symlink-path') }
            before do
              FileUtils.mkdir_p(real_path)
              File.symlink(real_path, log_path)
            end
            after do
              FileUtils.rm_rf(real_path)
              FileUtils.rm(log_path)
            end

            it "returns real path of log path" do
              expect(subject).to eq(File.join(real_path, 'appsignal.log'))
            end
          end
        end
      end
    end

    context "when there is a pre 0.12 style endpoint" do
      let(:config) { project_fixture_config('production', :endpoint => 'https://push.appsignal.com/1') }

      it "should strip the path" do
        subject[:endpoint].should eq 'https://push.appsignal.com'
      end
    end

    context "when there is an endpoint with a non-standard port" do
      let(:config) { project_fixture_config('production', :endpoint => 'http://localhost:4567') }

      it "should keep the port" do
        subject[:endpoint].should eq 'http://localhost:4567'
      end
    end

    describe "#[]= and #[]" do
      it "should get the value for an existing key" do
        subject[:push_api_key].should eq 'abc'
      end

      it "should change and get the value for an existing key" do
        subject[:push_api_key] = 'abcde'
        subject[:push_api_key].should eq 'abcde'
      end

      it "should return nil for a non-existing key" do
        subject[:nonsense].should be_nil
      end
    end

    describe "#write_to_environment" do
      before do
        subject.config_hash[:http_proxy]     = 'http://localhost'
        subject.config_hash[:ignore_actions] = ['action1', 'action2']
        subject.config_hash[:log_path]  = '/tmp'
        subject.config_hash[:hostname]  = 'app1.local'
        subject.config_hash[:filter_parameters] = %w(password confirm_password)
        subject.config_hash[:running_in_container] = false
        subject.write_to_environment
      end

      it "should write the current config to env vars" do
        ENV['APPSIGNAL_ACTIVE'].should                       eq 'true'
        ENV['APPSIGNAL_APP_PATH'].should                     end_with('spec/support/project_fixture')
        ENV['APPSIGNAL_AGENT_PATH'].should                   end_with('/ext')
        ENV['APPSIGNAL_DEBUG_LOGGING'].should                eq 'false'
        ENV['APPSIGNAL_LOG_FILE_PATH'].should                end_with('/tmp/appsignal.log')
        ENV['APPSIGNAL_PUSH_API_ENDPOINT'].should            eq 'https://push.appsignal.com'
        ENV['APPSIGNAL_PUSH_API_KEY'].should                 eq 'abc'
        ENV['APPSIGNAL_APP_NAME'].should                     eq 'TestApp'
        ENV['APPSIGNAL_ENVIRONMENT'].should                  eq 'production'
        ENV['APPSIGNAL_AGENT_VERSION'].should                eq Appsignal::Extension.agent_version
        ENV['APPSIGNAL_LANGUAGE_INTEGRATION_VERSION'].should eq Appsignal::VERSION
        ENV['APPSIGNAL_HTTP_PROXY'].should                   eq 'http://localhost'
        ENV['APPSIGNAL_IGNORE_ACTIONS'].should               eq 'action1,action2'
        ENV['APPSIGNAL_FILTER_PARAMETERS'].should            eq 'password,confirm_password'
        ENV['APPSIGNAL_SEND_PARAMS'].should                  eq 'true'
        ENV['APPSIGNAL_RUNNING_IN_CONTAINER'].should         eq 'false'
        ENV['APPSIGNAL_WORKING_DIR_PATH'].should             be_nil
        ENV['APPSIGNAL_ENABLE_HOST_METRICS'].should          eq 'true'
        ENV['APPSIGNAL_ENABLE_MINUTELY_PROBES'].should       eq 'false'
        ENV['APPSIGNAL_HOSTNAME'].should                     eq 'app1.local'
        ENV['APPSIGNAL_PROCESS_NAME'].should                 include 'rspec'
        ENV['APPSIGNAL_CA_FILE_PATH'].should                 eq File.join(resources_dir, "cacert.pem")
      end

      context "if working_dir_path is set" do
        before do
          subject.config_hash[:working_dir_path] = '/tmp/appsignal2'
          subject.write_to_environment
        end

        it "should write the current config to env vars" do
          ENV['APPSIGNAL_WORKING_DIR_PATH'].should eq '/tmp/appsignal2'
        end
      end
    end

    context "if the env is passed as a symbol" do
      let(:config) { project_fixture_config(:production) }

      its(:active?) { should be_true }
    end

    context "when there's config in the environment" do
      before do
        ENV['APPSIGNAL_PUSH_API_KEY'] = 'push_api_key'
        ENV['APPSIGNAL_DEBUG'] = 'true'
      end

      it "should ignore env vars that are present in the config file" do
        subject[:push_api_key].should eq 'abc'
      end

      it "should use env vars that are not present in the config file" do
        subject[:debug].should eq true
      end

      describe "running_in_container" do
        subject { config[:running_in_container] }

        context "when running on Heroku" do
          around { |example| recognize_as_heroku { example.run } }

          it "is set to true" do
            expect(subject).to be_true
          end
        end

        context "when running in container" do
          around { |example| recognize_as_container(:docker) { example.run } }

          it "is set to true" do
            expect(subject).to be_true
          end
        end

        context "when not running in container" do
          around { |example| recognize_as_container(:none) { example.run } }

          it "is set to false" do
            expect(subject).to be_false
          end
        end
      end
    end

    context "and there is an initial config" do
      let(:config) { project_fixture_config('production', :name => 'Initial name', :initial_key => 'value') }

      it "should merge with the config" do
        subject[:name].should eq 'TestApp'
        subject[:initial_key].should eq 'value'
      end
    end

    context "and there is an old-style config" do
      let(:config) { project_fixture_config('old_api_key') }

      it "should fill the push_api_key with the old style key" do
        subject[:push_api_key].should eq 'def'
      end

      it "should fill ignore_errors with the old style ignore exceptions" do
        subject[:ignore_errors].should eq ['StandardError']
      end
    end
  end

  context "when there is a config file without the current env" do
    let(:config) { project_fixture_config('nonsense') }

    it "should log an error" do
      Logger.any_instance.should_receive(:error).with(
        "Not loading from config file: config for 'nonsense' not found"
      ).once
      Logger.any_instance.should_receive(:error).with(
        "Push api key not set after loading config"
      ).once
      subject
    end

    its(:valid?)  { should be_false }
    its(:active?) { should be_false }
  end

  context "when there is no config file" do
    let(:initial_config) { {} }
    let(:config) { Appsignal::Config.new('/tmp', 'production', initial_config) }

    its(:valid?)        { should be_false }
    its(:active?)       { should be_false }
    its(:log_file_path) { should end_with('/tmp/appsignal.log') }

    context "with valid config in the environment" do
      before do
        ENV['APPSIGNAL_PUSH_API_KEY']   = 'aaa-bbb-ccc'
        ENV['APPSIGNAL_ACTIVE']         = 'true'
        ENV['APPSIGNAL_APP_NAME']       = 'App name'
        ENV['APPSIGNAL_DEBUG']          = 'true'
        ENV['APPSIGNAL_IGNORE_ACTIONS'] = 'action1,action2'
      end

      its(:valid?)  { should be_true }
      its(:active?) { should be_true }

      its([:push_api_key])   { should eq 'aaa-bbb-ccc' }
      its([:active])         { should eq true }
      its([:name])           { should eq 'App name' }
      its([:debug])          { should eq true }
      its([:ignore_actions]) { should eq ['action1', 'action2'] }
    end
  end

  context "when a nil root path is passed" do
    let(:initial_config) { {} }
    let(:config) { Appsignal::Config.new(nil, 'production', initial_config) }

    its(:valid?)  { should be_false }
    its(:active?) { should be_false }
  end
end
