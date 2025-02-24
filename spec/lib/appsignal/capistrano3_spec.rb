if DependencyHelper.capistrano3_present?
  require "capistrano/all"
  require "capistrano/deploy"
  require "appsignal/capistrano"

  describe "Capistrano 3 integration" do
    let(:capistrano) { Class.new.extend(Capistrano::DSL) }
    let(:env) { :production }
    let(:options) { {} }
    let(:config) { build_config(:env => env, :options => options) }
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:log_stream) { StringIO.new }
    let(:logs) { log_contents(log_stream) }
    let!(:capistrano_config) do
      Capistrano::Configuration.reset!
      Capistrano::Configuration.env.tap do |c|
        c.set(:log_level, :error)
        c.set(:rails_env, "production")
        c.set(:repository, "main")
        c.set(:deploy_to, "/home/username/app")
        c.set(:current_release, "")
        c.set(:current_revision, "503ce0923ed177a3ce000005")
      end
    end
    let(:marker_data) do
      {
        :revision => "503ce0923ed177a3ce000005",
        :user => "batman"
      }
    end
    before do
      Appsignal.internal_logger = test_logger(log_stream)
      Rake::Task["appsignal:deploy"].reenable
    end

    def run
      capture_std_streams(out_stream, out_stream) do
        capistrano.invoke("appsignal:deploy")
      end
    end

    it "should have a deploy task" do
      expect(Rake::Task.task_defined?("appsignal:deploy")).to be_truthy
    end

    describe "appsignal:deploy task" do
      before do
        ENV["USER"] = "batman"
      end

      context "with appsignal.rb config file" do
        def write_appsignal_rb_config_file(config_contents)
          test_path = File.join(tmp_dir, "config_file_test_#{SecureRandom.uuid}")
          FileUtils.mkdir_p(test_path)
          Dir.chdir(test_path) do
            write_file(File.join(test_path, "config", "appsignal.rb"), config_contents)
          end
          test_path
        end

        around do |example|
          tmp_config_dir = write_appsignal_rb_config_file(
            <<~CONFIG
              Appsignal.configure do |config|
                config.active = true
                config.name = "CapDSLapp"
                config.push_api_key = "cap_push_api_key"
              end
            CONFIG
          )
          Dir.chdir(tmp_config_dir) { example.run }
        end

        it "reads the base config from the config file" do
          marker_request = stub_marker_request(
            {
              :environment => "production",
              :name => "CapDSLapp",
              :push_api_key => "cap_push_api_key"
            },
            marker_data
          ).to_return(:status => 200)

          run

          expect(marker_request).to have_been_made
        end

        context "when rack_env is the only env set" do
          let(:env) { "rack_production" }
          before do
            capistrano_config.delete(:rails_env)
            capistrano_config.set(:rack_env, env)
          end

          it "uses the rack_env as the env" do
            marker_request = stub_marker_request(
              {
                :environment => "rack_production",
                :name => "CapDSLapp",
                :push_api_key => "cap_push_api_key"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end
        end

        context "when stage is set" do
          let(:env) { "stage_production" }
          before do
            capistrano_config.set(:rack_env, "rack_production")
            capistrano_config.set(:stage, env)
          end

          it "prefers the Capistrano stage rather than rails_env and rack_env" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "CapDSLapp",
                :push_api_key => "cap_push_api_key"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end
        end

        context "when `appsignal_config` is set" do
          before do
            ENV["APPSIGNAL_APP_NAME"] = "EnvName"
            capistrano_config.set(:appsignal_config, :name => "CapName")
          end

          it "overrides the default config with the custom appsignal_config" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "CapName",
                :push_api_key => "cap_push_api_key"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end

          context "with invalid config" do
            before do
              capistrano_config.set(:appsignal_config, :push_api_key => nil)
            end

            it "does not continue with invalid config" do
              run
              expect(output).to include \
                "Not notifying of deploy, config is not active for environment: production"
              expect(logs).to contains_log(:error, "Push API key not set after loading config")
            end
          end
        end

        context "when `appsignal_env` is set as a string" do
          let(:env) { "appsignal_production" }
          before do
            capistrano_config.set(:rack_env, "rack_production")
            capistrano_config.set(:stage, "stage_production")
            capistrano_config.set(:appsignal_env, env)
          end

          it "prefers the appsignal_env rather than stage, rails_env and rack_env" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "CapDSLapp",
                :push_api_key => "cap_push_api_key"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end
        end

        context "when `appsignal_env` is set as a symbol" do
          let(:env) { :appsignal_production }
          before do
            capistrano_config.set(:rack_env, "rack_production")
            capistrano_config.set(:stage, "stage_production")
            capistrano_config.set(:appsignal_env, env)
          end

          it "prefers the appsignal_env rather than stage, rails_env and rack_env" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "CapDSLapp",
                :push_api_key => "cap_push_api_key"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end
        end
      end

      context "with appsignal.yml config file" do
        let(:options) { { :name => "AppName" } }
        before do
          capistrano_config.set(
            :appsignal_config,
            :name => "AppName",
            :active => true,
            :push_api_key => "abc"
          )
        end
        around do |example|
          Dir.chdir project_fixture_path do
            example.run
          end
        end

        context "when rack_env is the only env set" do
          let(:env) { "rack_production" }
          before do
            capistrano_config.delete(:rails_env)
            capistrano_config.set(:rack_env, env)
          end

          it "uses the rack_env as the env" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "AppName",
                :push_api_key => "abc"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end
        end

        context "when stage is set" do
          let(:env) { "stage_production" }
          before do
            capistrano_config.set(:rack_env, "rack_production")
            capistrano_config.set(:stage, env)
          end

          it "prefers the Capistrano stage rather than rails_env and rack_env" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "AppName",
                :push_api_key => "abc"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end
        end

        context "when `appsignal_config` is set" do
          before do
            ENV["APPSIGNAL_APP_NAME"] = "EnvName"
            capistrano_config.set(:appsignal_config, :name => "CapName")
          end

          it "overrides the default config with the custom appsignal_config" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "CapName",
                :push_api_key => "abc"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end

          context "with invalid config" do
            before do
              capistrano_config.set(:appsignal_config, :push_api_key => nil)
            end

            it "does not continue with invalid config" do
              run
              expect(output).to include \
                "Not notifying of deploy, config is not active for environment: production"
              expect(logs).to contains_log(:error, "Push API key not set after loading config")
            end
          end
        end

        context "when `appsignal_env` is set" do
          let(:env) { "appsignal_production" }
          before do
            capistrano_config.set(:rack_env, "rack_production")
            capistrano_config.set(:stage, "stage_production")
            capistrano_config.set(:appsignal_env, env)
          end

          it "prefers the appsignal_env rather than stage, rails_env and rack_env" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "AppName",
                :push_api_key => "abc"
              },
              marker_data
            ).to_return(:status => 200)

            run

            expect(marker_request).to have_been_made
          end
        end
      end

      describe "markers" do
        around do |example|
          Dir.chdir project_fixture_path do
            example.run
          end
        end

        context "when active for this environment" do
          it "transmits marker" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "TestApp",
                :push_api_key => "abc"
              },
              marker_data
            ).to_return(:status => 200)
            run

            expect(output).to include \
              "Notifying AppSignal of '#{env}' deploy with revision: 503ce0923ed177a3ce000005, " \
                "user: batman",
              "AppSignal has been notified of this deploy!"

            expect(marker_request).to have_been_made
          end

          context "with overridden revision" do
            before do
              capistrano_config.set(:appsignal_revision, "abc123")
            end

            it "transmits the overridden revision" do
              marker_request = stub_marker_request(
                {
                  :environment => env.to_s,
                  :name => "TestApp",
                  :push_api_key => "abc"
                },
                :revision => "abc123",
                :user => "batman"
              ).to_return(:status => 200)

              run

              expect(output).to include \
                "Notifying AppSignal of '#{env}' deploy with revision: abc123, user: batman",
                "AppSignal has been notified of this deploy!"

              expect(marker_request).to have_been_made
            end
          end

          context "with overridden deploy user" do
            before do
              capistrano_config.set(:appsignal_user, "robin")
            end

            it "transmits the overridden deploy user" do
              marker_request = stub_marker_request(
                {
                  :environment => env.to_s,
                  :name => "TestApp",
                  :push_api_key => "abc"
                },
                :revision => "503ce0923ed177a3ce000005",
                :user => "robin"
              ).to_return(:status => 200)

              run

              expect(output).to include \
                "Notifying AppSignal of '#{env}' deploy with revision: 503ce0923ed177a3ce000005, " \
                  "user: robin",
                "AppSignal has been notified of this deploy!"

              expect(marker_request).to have_been_made
            end
          end

          if Gem::Version.new(Capistrano::VERSION) >= Gem::Version.new("3.5.0")
            context "when dry run" do
              before do
                expect(capistrano_config).to receive(:dry_run?).and_return(true)
                run
              end

              it "does not transmit the marker" do
                expect(output).to include "Dry run: AppSignal deploy marker not actually sent."
              end
            end
          end

          context "with failed request" do
            it "does not transmit marker" do
              marker_request = stub_marker_request(
                {
                  :environment => env.to_s,
                  :name => "TestApp",
                  :push_api_key => "abc"
                },
                marker_data
              ).to_return(:status => 500)
              run

              expect(output).to include \
                "Notifying AppSignal of '#{env}' deploy with " \
                  "revision: 503ce0923ed177a3ce000005, " \
                  "user: batman",
                "Something went wrong while trying to notify AppSignal:"
              expect(output).to_not include "AppSignal has been notified of this deploy!"

              expect(marker_request).to have_been_made
            end
          end
        end

        context "when not active for this environment" do
          before do
            capistrano_config.set(:rails_env, "nonsense")
            run
          end

          it "should not send deploy marker" do
            expect(output).to include \
              "Not notifying of deploy, config is not active for environment: nonsense"
          end
        end
      end
    end
  end
end
