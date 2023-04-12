if DependencyHelper.capistrano3_present?
  require "capistrano/all"
  require "capistrano/deploy"
  require "appsignal/capistrano"

  describe "Capistrano 3 integration" do
    let(:capistrano) { Class.new.extend(Capistrano::DSL) }
    let(:config) { project_fixture_config }
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:logger) { Logger.new(out_stream) }
    let!(:capistrano_config) do
      Capistrano::Configuration.reset!
      Capistrano::Configuration.env.tap do |c|
        c.set(:log_level, :error)
        c.set(:logger, logger)
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
    before { Rake::Task["appsignal:deploy"].reenable }

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
      around do |example|
        Dir.chdir project_fixture_path do
          example.run
        end
      end

      context "config" do
        let(:env) { "production" }
        before do
          capistrano_config.set(
            :appsignal_config,
            :name => "AppName",
            :active => true,
            :push_api_key => "abc"
          )
          config[:name] = "AppName"
          config.instance_variable_set(:@env, env)
          stub_marker_request.to_return(:status => 200)
        end

        context "when rack_env is the only env set" do
          let(:env) { "rack_production" }
          before do
            capistrano_config.delete(:rails_env)
            capistrano_config.set(:rack_env, env)
          end

          it "uses the rack_env as the env" do
            original_new = Appsignal::Marker.method(:new)

            expect(Appsignal::Marker).to receive(:new) do |data, given_config|
              expect(given_config.env).to eq("rack_production")
              original_new.call(data, given_config)
            end

            run
          end
        end

        context "when stage is set" do
          let(:env) { "stage_production" }
          before do
            capistrano_config.set(:rack_env, "rack_production")
            capistrano_config.set(:stage, env)
          end

          it "prefers the Capistrano stage rather than rails_env and rack_env" do
            original_new = Appsignal::Marker.method(:new)

            expect(Appsignal::Marker).to receive(:new) do |data, given_config|
              expect(given_config.env).to eq("stage_production")
              original_new.call(data, given_config)
            end

            run
          end
        end

        context "when `appsignal_config` is set" do
          before do
            ENV["APPSIGNAL_APP_NAME"] = "EnvName"
            capistrano_config.set(:appsignal_config, :name => "AppName")
            config[:name] = "AppName"
          end

          it "overrides the default config with the custom appsignal_config" do
            original_new = Appsignal::Marker.method(:new)

            expect(Appsignal::Marker).to receive(:new) do |data, given_config|
              expect(given_config[:name]).to eq("AppName")
              original_new.call(data, given_config)
            end

            run
          end

          context "with invalid config" do
            before do
              capistrano_config.set(:appsignal_config, :push_api_key => nil)
            end

            it "does not continue with invalid config" do
              run
              expect(output).to include \
                "Not notifying of deploy, config is not active for environment: production"
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
            original_new = Appsignal::Marker.method(:new)

            expect(Appsignal::Marker).to receive(:new) do |data, given_config|
              expect(given_config.env).to eq("appsignal_production")
              original_new.call(data, given_config)
            end

            run
          end
        end
      end

      describe "markers" do
        context "when active for this environment" do
          it "transmits marker" do
            stub_marker_request.to_return(:status => 200)
            run

            expect(output).to include \
              "Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, " \
                "user: batman",
              "AppSignal has been notified of this deploy!"
          end

          context "with overridden revision" do
            before do
              capistrano_config.set(:appsignal_revision, "abc123")
              stub_marker_request(:revision => "abc123").to_return(:status => 200)
              run
            end

            it "transmits the overriden revision" do
              expect(output).to include \
                "Notifying AppSignal of deploy with: revision: abc123, user: batman",
                "AppSignal has been notified of this deploy!"
            end
          end

          context "with overridden deploy user" do
            before do
              capistrano_config.set(:appsignal_user, "robin")
              stub_marker_request(:user => "robin").to_return(:status => 200)
              run
            end

            it "transmits the overriden deploy user" do
              expect(output).to include \
                "Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, " \
                  "user: robin",
                "AppSignal has been notified of this deploy!"
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
            before do
              stub_marker_request.to_return(:status => 500)
              run
            end

            it "does not transmit marker" do
              expect(output).to include \
                "Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, " \
                  "user: batman",
                "Something went wrong while trying to notify AppSignal:"
              expect(output).to_not include "AppSignal has been notified of this deploy!"
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

  def stub_marker_request(data = {})
    stub_api_request config, "markers", marker_data.merge(data)
  end
end
