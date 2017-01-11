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
        c.set(:repository, "master")
        c.set(:deploy_to, "/home/username/app")
        c.set(:current_release, "")
        c.set(:current_revision, "503ce0923ed177a3ce000005")
      end
    end
    before { Rake::Task["appsignal:deploy"].reenable }

    def run
      capture_std_streams(out_stream, out_stream) do
        capistrano.invoke("appsignal:deploy")
      end
    end

    it "should have a deploy task" do
      Rake::Task.task_defined?("appsignal:deploy").should be_true
    end

    describe "appsignal:deploy task" do
      before do
        ENV["USER"] = "batman"
        ENV["PWD"] = project_fixture_path
      end

      context "config" do
        it "should be instantiated with the right params" do
          Appsignal::Config.should_receive(:new).with(
            project_fixture_path,
            "production",
            {},
            kind_of(Logger)
          )
        end

        context "when appsignal_config is available" do
          before do
            capistrano_config.set(:appsignal_config, :name => "AppName")
          end

          it "should be instantiated with the right params" do
            Appsignal::Config.should_receive(:new).with(
              project_fixture_path,
              "production",
              { :name => "AppName" },
              kind_of(Logger)
            )
          end

          context "when rack_env is the only env set" do
            before do
              capistrano_config.delete(:rails_env)
              capistrano_config.set(:rack_env, "rack_production")
            end

            it "should be instantiated with the rack env" do
              Appsignal::Config.should_receive(:new).with(
                project_fixture_path,
                "rack_production",
                { :name => "AppName" },
                kind_of(Logger)
              )
            end
          end

          context "when stage is set" do
            before do
              capistrano_config.set(:rack_env, "rack_production")
              capistrano_config.set(:stage, "stage_production")
            end

            it "should prefer the stage rather than rails_env and rack_env" do
              Appsignal::Config.should_receive(:new).with(
                project_fixture_path,
                "stage_production",
                { :name => "AppName" },
                kind_of(Logger)
              )
            end
          end

          context "when appsignal_env is set" do
            before do
              capistrano_config.set(:rack_env, "rack_production")
              capistrano_config.set(:stage, "stage_production")
              capistrano_config.set(:appsignal_env, "appsignal_production")
            end

            it "should prefer the appsignal_env rather than stage, rails_env and rack_env" do
              Appsignal::Config.should_receive(:new).with(
                project_fixture_path,
                "appsignal_production",
                { :name => "AppName" },
                kind_of(Logger)
              )
            end
          end
        end

        after { run }
      end

      describe "markers" do
        def stub_marker_request(data = {})
          stub_api_request config, "markers", marker_data.merge(data)
        end

        let(:marker_data) do
          {
            :revision => "503ce0923ed177a3ce000005",
            :user => "batman"
          }
        end

        context "when active for this environment" do
          it "transmits marker" do
            stub_marker_request.to_return(:status => 200)
            run

            expect(output).to include \
              "Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman",
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

          context "with failed request" do
            before do
              stub_marker_request.to_return(:status => 500)
              run
            end

            it "does not transmit marker" do
              expect(output).to include \
                "Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman",
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
end
