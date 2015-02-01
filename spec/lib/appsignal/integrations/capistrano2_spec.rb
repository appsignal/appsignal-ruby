require 'spec_helper'

if capistrano2_present?
  require 'capistrano'
  require 'capistrano/configuration'
  require 'appsignal/capistrano'

  describe "Capistrano 2 integration" do
    let(:config) { project_fixture_config }

    before :all do
      @capistrano_config = Capistrano::Configuration.new
      Appsignal::Integrations::Capistrano.tasks(@capistrano_config)
    end

    it "should have a deploy task" do
      @capistrano_config.find_task('appsignal:deploy').should_not be_nil
    end

    describe "appsignal:deploy task" do
      before do
        @capistrano_config.set(:rails_env, 'production')
        @capistrano_config.set(:repository, 'master')
        @capistrano_config.set(:deploy_to, '/home/username/app')
        @capistrano_config.set(:current_release, '')
        @capistrano_config.set(:current_revision, '503ce0923ed177a3ce000005')
        @capistrano_config.dry_run = false
        ENV['USER'] = 'batman'
        ENV['PWD'] = project_fixture_path
      end

      context "config" do
        before do
          @capistrano_config.dry_run = true
        end

        it "should be instantiated with the right params" do
          Appsignal::Config.should_receive(:new).with(
            project_fixture_path,
            'production',
            {},
            kind_of(Capistrano::Logger)
          )
        end

        context "when appsignal_config is available" do
          before do
            @capistrano_config.set(:appsignal_config, :name => 'AppName')
          end

          it "should be instantiated with the right params" do
            Appsignal::Config.should_receive(:new).with(
              project_fixture_path,
              'production',
              {:name => 'AppName'},
              kind_of(Capistrano::Logger)
            )
          end

          context "when rack_env is used instead of rails_env" do
            before do
              @capistrano_config.unset(:rails_env)
              @capistrano_config.set(:rack_env, 'rack_production')
            end

            it "should be instantiated with the right params" do
              Appsignal::Config.should_receive(:new).with(
                project_fixture_path,
                'rack_production',
                {:name => 'AppName'},
                kind_of(Capistrano::Logger)
              )
            end
          end
        end

        after { @capistrano_config.find_and_execute_task('appsignal:deploy') }
      end

      context "send marker" do
        before :all do
          @io = StringIO.new
          @logger = Capistrano::Logger.new(:output => @io)
          @logger.level = Capistrano::Logger::MAX_LEVEL
          @capistrano_config.logger = @logger
        end

        let(:marker_data) do
          {
            :revision => '503ce0923ed177a3ce000005',
            :user => 'batman'
          }
        end

        context "when active for this environment" do
          before do
            @marker = Appsignal::Marker.new(
              marker_data,
              config,
              @logger
            )
            Appsignal::Marker.stub(:new => @marker)
          end

          context "proper setup" do
            it "should add the correct marker data" do
              Appsignal::Marker.should_receive(:new).with(
                marker_data,
                kind_of(Appsignal::Config),
                kind_of(Capistrano::Logger)
              ).and_return(@marker)

              @capistrano_config.find_and_execute_task('appsignal:deploy')
            end

            it "should transmit data" do
              Appsignal::Native.should_receive(:transmit_marker).and_return(200)
              @capistrano_config.find_and_execute_task('appsignal:deploy')
              @io.string.should include('Notifying Appsignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman')
              @io.string.should include('Appsignal has been notified of this deploy!')
            end

            context "with overridden revision" do
              before do
                @capistrano_config.set(:appsignal_revision, 'abc123')
              end
              it "should add the correct marker data" do
                Appsignal::Marker.should_receive(:new).with(
                  {
                    :revision => 'abc123',
                    :user => 'batman'
                  },
                  kind_of(Appsignal::Config),
                  kind_of(Capistrano::Logger)
                ).and_return(@marker)

                @capistrano_config.find_and_execute_task('appsignal:deploy')
              end
            end
          end

          context "dry run" do
            before { @capistrano_config.dry_run = true }

            it "should not send deploy marker" do
              @marker.should_not_receive(:transmit)
              @capistrano_config.find_and_execute_task('appsignal:deploy')
              @io.string.should include('Dry run: Deploy marker not actually sent.')
            end
          end
        end

        context "when not active for this environment" do
          before do
            @capistrano_config.set(:rails_env, 'nonsense')
          end

          it "should not send deploy marker" do
            Appsignal::Marker.should_not_receive(:new)
            @capistrano_config.find_and_execute_task('appsignal:deploy')
            @io.string.should include("Not loading: config for 'nonsense' not found")
          end
        end
      end
    end
  end
end
