require 'spec_helper'
require 'appsignal/capistrano'
require 'capistrano/configuration'

describe Appsignal::Capistrano do
  let(:config) { project_fixture_config }

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
    end

    context "config" do
      before { @capistrano_config.dry_run = true }

      it "should be instantiated with the right params" do
        Appsignal::Config.should_receive(:new).with(
          ENV['PWD'],
          'production',
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
            ENV['PWD'],
            'rack_production',
            kind_of(Capistrano::Logger)
          )
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
          :revision => "503ce0923ed177a3ce000005",
          :repository => "master",
          :user => "batman"
        }
      end

      before do
        @marker = Appsignal::Marker.new(
          marker_data,
          config,
          @logger
        )
        Appsignal::Marker.should_receive(:new).with(
          marker_data,
          kind_of(Appsignal::Config),
          kind_of(Capistrano::Logger)
        ).and_return(@marker)
      end

      context "proper setup" do
        before do
          @transmitter = double
          Appsignal::Transmitter.should_receive(:new).and_return(@transmitter)
        end

        it "should transmit data" do
          @transmitter.should_receive(:transmit).and_return('200')
          @capistrano_config.find_and_execute_task('appsignal:deploy')
          @io.string.should include('** Notifying Appsignal of deploy...')
          @io.string.should include(
            '** Appsignal has been notified of this deploy!'
          )
        end
      end

      it "should not transmit data" do
        @capistrano_config.find_and_execute_task('appsignal:deploy')
        @io.string.should include('** Notifying Appsignal of deploy...')
        @io.string.should include(
          '** Something went wrong while trying to notify Appsignal:'
        )
      end

      context "dry run" do
        before { @capistrano_config.dry_run = true }

        it "should not send deploy marker" do
          @marker.should_not_receive(:transmit)
          @capistrano_config.find_and_execute_task('appsignal:deploy')
          @io.string.should include(
            '** Dry run: Deploy marker not actually sent.'
          )
        end
      end
    end
  end
end
