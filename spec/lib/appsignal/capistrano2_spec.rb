if DependencyHelper.capistrano2_present?
  require 'capistrano'
  require 'capistrano/configuration'
  require 'appsignal/capistrano'

  describe "Capistrano 2 integration" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:config) { project_fixture_config }
    let(:capistrano_config) do
      Capistrano::Configuration.new.tap do |c|
        c.set(:rails_env, 'production')
        c.set(:repository, 'master')
        c.set(:deploy_to, '/home/username/app')
        c.set(:current_release, '')
        c.set(:current_revision, '503ce0923ed177a3ce000005')
        c.dry_run = false
      end
    end
    before { Appsignal::Capistrano.tasks(capistrano_config) }

    def run
      capture_stdout(out_stream) do
        capistrano_config.find_and_execute_task('appsignal:deploy')
      end
    end

    it "should have a deploy task" do
      capistrano_config.find_task('appsignal:deploy').should_not be_nil
    end

    describe "appsignal:deploy task" do
      before do
        ENV['USER'] = 'batman'
        ENV['PWD'] = project_fixture_path
      end

      context "config" do
        before do
          capistrano_config.dry_run = true
        end

        it "should be instantiated with the right params" do
          Appsignal::Config.should_receive(:new).with(
            project_fixture_path,
            'production',
            {},
            kind_of(Logger)
          )
        end

        context "when appsignal_config is available" do
          before do
            capistrano_config.set(:appsignal_config, :name => 'AppName')
          end

          it "should be instantiated with the right params" do
            Appsignal::Config.should_receive(:new).with(
              project_fixture_path,
              'production',
              {:name => 'AppName'},
              kind_of(Logger)
            )
          end

          context "when rack_env is used instead of rails_env" do
            before do
              capistrano_config.unset(:rails_env)
              capistrano_config.set(:rack_env, 'rack_production')
            end

            it "should be instantiated with the right params" do
              Appsignal::Config.should_receive(:new).with(
                project_fixture_path,
                'rack_production',
                {:name => 'AppName'},
                kind_of(Logger)
              )
            end
          end

          context "when stage is used instead of rack_env / rails_env" do
            before do
              capistrano_config.unset(:rails_env)
              capistrano_config.set(:stage, 'stage_production')
            end

            it "should be instantiated with the right params" do
              Appsignal::Config.should_receive(:new).with(
                project_fixture_path,
                'stage_production',
                {:name => 'AppName'},
                kind_of(Logger)
              )
            end
          end

          context "when appsignal_env is set" do
            before do
              capistrano_config.set(:rack_env, 'rack_production')
              capistrano_config.set(:stage, 'stage_production')
              capistrano_config.set(:appsignal_env, 'appsignal_production')
            end

            it "should prefer the appsignal_env rather than stage, rails_env and rack_env" do
              Appsignal::Config.should_receive(:new).with(
                project_fixture_path,
                'appsignal_production',
                {:name => 'AppName'},
                kind_of(Logger)
              )
            end
          end
        end

        after { run }
      end

      describe "markers" do
        def stub_marker_request(data = {})
          stub_api_request config, 'markers', marker_data.merge(data)
        end

        let(:marker_data) do
          {
            :revision => '503ce0923ed177a3ce000005',
            :user => 'batman'
          }
        end

        context "when active for this environment" do
          it "transmits marker" do
            stub_marker_request.to_return(:status => 200)
            run

            expect(output).to include \
              'Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman',
              'AppSignal has been notified of this deploy!'
          end

          context "with overridden revision" do
            before do
              capistrano_config.set(:appsignal_revision, 'abc123')
              stub_marker_request(:revision => 'abc123').to_return(:status => 200)
              run
            end

            it "transmits the overriden revision" do
              expect(output).to include \
                'Notifying AppSignal of deploy with: revision: abc123, user: batman',
                'AppSignal has been notified of this deploy!'
            end
          end

          context "with failed request" do
            before do
              stub_marker_request.to_return(:status => 500)
              run
            end

            it "does not transmit marker" do
              expect(output).to include \
                'Notifying AppSignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman',
                'Something went wrong while trying to notify AppSignal:'
              expect(output).to_not include 'AppSignal has been notified of this deploy!'
            end
          end

          context "when dry run" do
            before do
              capistrano_config.dry_run = true
              run
            end

            it "does not transmit marker" do
              expect(output).to include \
                'Dry run: AppSignal deploy marker not actually sent.'
            end
          end
        end

        context "when not active for this environment" do
          before do
            capistrano_config.set(:rails_env, 'nonsense')
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
