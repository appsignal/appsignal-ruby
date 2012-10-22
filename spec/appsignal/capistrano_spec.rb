require 'spec_helper'
require 'capistrano/configuration'

describe Appsignal::Capistrano do
  before :all do
    @config = Capistrano::Configuration.new
    Appsignal::Capistrano.tasks(@config)
  end

  it "should have a deploy task" do
    @config.find_task('appsignal:deploy').should_not be_nil
  end

  describe "appsignal:deploy task" do
    before :all do
      @config.set(:rails_env, 'development')
      @config.set(:repository, 'master')
      @config.set(:deploy_to, '/home/username/app')
      @config.set(:current_release, '')
      @config.set(:current_revision, '503ce0923ed177a3ce000005')
      ENV['USER'] = 'batman'
    end

    context "send marker" do
      let(:marker_data) {
        {
          :revision => "503ce0923ed177a3ce000005",
          :repository => "master",
          :user => "batman"
        }
      }

      before do
        @marker = mock()
        Appsignal::Marker.should_receive(:new).
          with(marker_data, Rails.root.to_s, 'development', anything()).
          and_return(@marker)
      end

      it "should transmit data" do
        @marker.should_receive(:transmit)

        @config.find_and_execute_task('appsignal:deploy')
      end
    end
  end
end
