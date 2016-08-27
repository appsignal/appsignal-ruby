if capistrano3_present?
  require 'capistrano/all'
  require 'capistrano/deploy'
  require 'appsignal/capistrano'

  include Capistrano::DSL

  describe "Capistrano 3 integration" do
    let(:config) { project_fixture_config }
    let(:out_stream) { StringIO.new }
    let(:logger) { Logger.new(out_stream) }

    before do
      @capistrano_config = Capistrano::Configuration.env
      @capistrano_config.set(:log_level, :error)
      @capistrano_config.set(:logger, logger)
    end
    before do
      @original_stdout = $stdout
      $stdout = out_stream
      @original_stderr = $stderr
      $stderr = out_stream
    end
    after do
      $stdout = @original_stdout
      $stderr = @original_stderr
      Rake::Task['appsignal:deploy'].reenable
    end

    it "should have a deploy task" do
      Rake::Task.task_defined?('appsignal:deploy').should be_true
    end

    describe "appsignal:deploy task" do
      before do
        @capistrano_config.set(:rails_env, 'production')
        @capistrano_config.set(:repository, 'master')
        @capistrano_config.set(:deploy_to, '/home/username/app')
        @capistrano_config.set(:current_release, '')
        @capistrano_config.set(:current_revision, '503ce0923ed177a3ce000005')
        ENV['USER'] = 'batman'
        ENV['PWD'] = project_fixture_path
      end

      context "config" do
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
            @capistrano_config.set(:appsignal_config, :name => 'AppName')
          end

          it "should be instantiated with the right params" do
            Appsignal::Config.should_receive(:new).with(
              project_fixture_path,
              'production',
              {:name => 'AppName'},
              kind_of(Logger)
            )
          end

          context "when rack_env is the only env set" do
            before do
              @capistrano_config.delete(:rails_env)
              @capistrano_config.set(:rack_env, 'rack_production')
            end

            it "should be instantiated with the rack env" do
              Appsignal::Config.should_receive(:new).with(
                project_fixture_path,
                'rack_production',
                {:name => 'AppName'},
                kind_of(Logger)
              )
            end
          end

          context "when stage is set" do
            before do
              @capistrano_config.set(:rack_env, 'rack_production')
              @capistrano_config.set(:stage, 'stage_production')
            end

            it "should prefer the stage rather than rails_env and rack_env" do
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
              @capistrano_config.set(:rack_env, 'rack_production')
              @capistrano_config.set(:stage, 'stage_production')
              @capistrano_config.set(:appsignal_env, 'appsignal_production')
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

        after do
          invoke('appsignal:deploy')
          @capistrano_config.delete(:stage)
          @capistrano_config.delete(:rack_env)
          @capistrano_config.delete(:appsignal_env)
        end
      end

      context "send marker" do
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
              config
            )
            Appsignal::Marker.stub(:new => @marker)
          end

          context "proper setup" do
            before do
              @transmitter = double
              Appsignal::Transmitter.should_receive(:new).and_return(@transmitter)
            end

            it "should add the correct marker data" do
              Appsignal::Marker.should_receive(:new).with(
                marker_data,
                kind_of(Appsignal::Config)
              ).and_return(@marker)

              invoke('appsignal:deploy')
            end

            it "should transmit data" do
              @transmitter.should_receive(:transmit).and_return('200')
              invoke('appsignal:deploy')
              out_stream.string.should include('Notifying Appsignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman')
              out_stream.string.should include('ppsignal has been notified of this deploy!')
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
                  kind_of(Appsignal::Config)
                ).and_return(@marker)

                invoke('appsignal:deploy')
              end
            end
          end

          it "should not transmit data" do
            invoke('appsignal:deploy')
            out_stream.string.should include('Notifying Appsignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman')
            out_stream.string.should include('Something went wrong while trying to notify Appsignal:')
          end
        end

        context "when not active for this environment" do
          before do
            @capistrano_config.set(:rails_env, 'nonsense')
          end

          it "should not send deploy marker" do
            Appsignal::Marker.should_not_receive(:new)
            invoke('appsignal:deploy')
            out_stream.string.should include("Not notifying of deploy, config is not active")
          end
        end
      end
    end
  end
end
