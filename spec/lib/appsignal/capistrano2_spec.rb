if DependencyHelper.capistrano2_present?
  require "capistrano"
  require "capistrano/configuration"
  require "appsignal/capistrano"

  describe "Capistrano 2 integration" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:env) { :production }
    let(:options) { {} }
    let(:config) { build_config(:env => env, :options => options) }
    let(:log_stream) { StringIO.new }
    let(:logs) { log_contents(log_stream) }
    let(:capistrano_config) do
      Capistrano::Configuration.new.tap do |c|
        c.set(:rails_env, "production")
        c.set(:repository, "main")
        c.set(:deploy_to, "/home/username/app")
        c.set(:current_release, "")
        c.set(:current_revision, "503ce0923ed177a3ce000005")
        c.dry_run = false
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
      Appsignal::Integrations::Capistrano.tasks(capistrano_config)
    end

    def run
      capture_stdout(out_stream) do
        capistrano_config.find_and_execute_task("appsignal:deploy")
      end
    end

    it "has a deploy task" do
      expect(capistrano_config.find_task("appsignal:deploy")).to_not be_nil
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
            capistrano_config.unset(:rails_env)
            capistrano_config.set(:rack_env, env)
          end

          it "uses the rack_env as the env" do
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
        around do |example|
          Dir.chdir project_fixture_path do
            example.run
          end
        end

        context "when appsignal_config is available" do
          before do
            capistrano_config.set(
              :appsignal_config,
              :name => "AppName",
              :active => true,
              :push_api_key => "abc"
            )
          end

          it "overrides the default config with the custom appsignal_config" do
            marker_request = stub_marker_request(
              {
                :environment => env.to_s,
                :name => "AppName",
                :push_api_key => "abc"
              },
              marker_data
            )

            run

            expect(marker_request).to have_been_made
          end

          context "when rack_env is used instead of rails_env" do
            before do
              capistrano_config.unset(:rails_env)
              capistrano_config.set(:rack_env, "rack_production")
            end

            it "uses the rack_env as the env" do
              marker_request = stub_marker_request(
                {
                  :environment => "rack_production",
                  :name => "AppName",
                  :push_api_key => "abc"
                },
                marker_data
              )

              run

              expect(marker_request).to have_been_made
            end
          end

          context "when stage is used instead of rack_env / rails_env" do
            before do
              capistrano_config.unset(:rails_env)
              capistrano_config.set(:stage, "stage_production")
            end

            it "uses the stage as the env" do
              marker_request = stub_marker_request(
                {
                  :environment => "stage_production",
                  :name => "AppName",
                  :push_api_key => "abc"
                },
                marker_data
              )

              run

              expect(marker_request).to have_been_made
            end
          end

          context "when appsignal_env is set" do
            before do
              capistrano_config.set(:rack_env, "rack_production")
              capistrano_config.set(:stage, "stage_production")
              capistrano_config.set(:appsignal_env, "appsignal_production")
            end

            it "uses the appsignal_env as the env" do
              marker_request = stub_marker_request(
                {
                  :environment => "appsignal_production",
                  :name => "AppName",
                  :push_api_key => "abc"
                },
                marker_data
              )

              run

              expect(marker_request).to have_been_made
            end
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
      end

      describe "markers" do
        around do |example|
          Dir.chdir project_fixture_path do
            example.run
          end
        end

        context "when active for this environment" do
          it "transmits marker" do
            marker_request = stub_marker_request(config, marker_data).to_return(:status => 200)
            run

            expect(output).to include \
              "Notifying AppSignal of 'production' deploy with " \
                "revision: 503ce0923ed177a3ce000005, " \
                "user: batman",
              "AppSignal has been notified of this deploy!"

            expect(marker_request).to have_been_made
          end

          context "with overridden revision" do
            before do
              capistrano_config.set(:appsignal_revision, "abc123")
            end

            it "transmits the overridden revision" do
              marker_request = stub_marker_request(config, marker_data.merge(:revision => "abc123"))
                .to_return(:status => 200)
              run

              expect(output).to include \
                "Notifying AppSignal of 'production' deploy with revision: abc123, user: batman",
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
                config,
                :revision => "503ce0923ed177a3ce000005",
                :user => "robin"
              ).to_return(:status => 200)

              run

              expect(output).to include \
                "Notifying AppSignal of 'production' deploy with " \
                  "revision: 503ce0923ed177a3ce000005, " \
                  "user: robin",
                "AppSignal has been notified of this deploy!"

              expect(marker_request).to have_been_made
            end
          end

          context "with failed request" do
            it "does not transmit marker" do
              marker_request = stub_marker_request(
                config,
                marker_data
              ).to_return(:status => 500)

              run

              expect(output).to include \
                "Notifying AppSignal of 'production' deploy with " \
                  "revision: 503ce0923ed177a3ce000005, " \
                  "user: batman",
                "Something went wrong while trying to notify AppSignal:"
              expect(output).to_not include "AppSignal has been notified of this deploy!"

              expect(marker_request).to have_been_made
            end
          end

          context "when dry run" do
            before do
              capistrano_config.dry_run = true
              run
            end

            it "does not transmit marker" do
              expect(output).to include \
                "Dry run: AppSignal deploy marker not actually sent."
            end
          end
        end

        context "when not active for this environment" do
          before do
            capistrano_config.set(:rails_env, "nonsense")
            run
          end

          it "does not transmit marker" do
            expect(output).to include \
              "Not notifying of deploy, config is not active for environment: nonsense"
          end
        end
      end
    end
  end
end
