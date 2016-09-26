if DependencyHelper.capistrano2_present?
  require 'capistrano'
  require 'capistrano/configuration'
  require 'appsignal/capistrano'

  describe "Capistrano 2 integration" do
    let(:out_stream) { StringIO.new }
    let(:config) { project_fixture_config }

    before do
      @original_stdout = $stdout
      $stdout = out_stream
    end
    after do
      $stdout = @original_stdout
    end

    before :all do
      @capistrano_config = Capistrano::Configuration.new
      Appsignal::Capistrano.tasks(@capistrano_config)
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
                kind_of(Logger)
              )
            end
          end

          context "when stage is used instead of rack_env / rails_env" do
            before do
              @capistrano_config.unset(:rails_env)
              @capistrano_config.set(:stage, 'stage_production')
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
          @capistrano_config.find_and_execute_task('appsignal:deploy')
          @capistrano_config.unset(:stage)
          @capistrano_config.unset(:rack_env)
          @capistrano_config.unset(:appsignal_env)
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

              @capistrano_config.find_and_execute_task('appsignal:deploy')
            end

            it "should transmit data" do
              @transmitter.should_receive(:transmit).and_return('200')
              @capistrano_config.find_and_execute_task('appsignal:deploy')
              out_stream.string.should include('Notifying Appsignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman')
              out_stream.string.should include('Appsignal has been notified of this deploy!')
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

                @capistrano_config.find_and_execute_task('appsignal:deploy')
              end
            end
          end

          it "should not transmit data" do
            @capistrano_config.find_and_execute_task('appsignal:deploy')
            out_stream.string.should include('Notifying Appsignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman')
            out_stream.string.should include('Something went wrong while trying to notify Appsignal:')
          end

          context "dry run" do
            before { @capistrano_config.dry_run = true }

            it "should not send deploy marker" do
              @marker.should_not_receive(:transmit)
              @capistrano_config.find_and_execute_task('appsignal:deploy')
              out_stream.string.should include('Dry run: AppSignal deploy marker not actually sent.')
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
            out_stream.string.should include('Not notifying of deploy, config is not active for environment: nonsense')
          end
        end
      end
    end
  end
end
