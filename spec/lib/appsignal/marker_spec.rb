require 'spec_helper'

describe Appsignal::Marker do
  let(:config) { project_fixture_config }
  let(:marker) {
    Appsignal::Marker.new(
      {
        :revision => '503ce0923ed177a3ce000005',
        :repository => 'master',
        :user => 'batman',
        :rails_env => 'production'
      },
      config,
      logger
    )
  }
  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }

  context "transmit" do
    it "should transmit data" do
      Appsignal::Native.should_receive(:transmit_marker).with(
        '{"revision":"503ce0923ed177a3ce000005","repository":"master","user":"batman","rails_env":"production"}',
        'json'
      )

      marker.transmit
    end

    context "logs" do
      shared_examples_for "logging info and errors" do
        it "should log status 200" do
          Appsignal::Native.should_receive(:transmit_marker).and_return(200)

          marker.transmit

          log.string.should include('Notifying Appsignal of deploy with: revision: 503ce0923ed177a3ce000005, user: batman')
          log.string.should include('Appsignal has been notified of this deploy!')
        end

        it "should log a status other than 200" do
          Appsignal::Native.should_receive(:transmit_marker).and_return(401)

          marker.transmit

          log.string.should include('401 when transmitting marker to https://push.appsignal.com')
        end
      end

      it_should_behave_like "logging info and errors"

      if capistrano2_present?
        require 'capistrano'

        context "with a Capistrano 2 logger" do
          let(:logger) {
            Capistrano::Logger.new(:output => log).tap do |logger|
              logger.level = Capistrano::Logger::MAX_LEVEL
            end
          }

          it_should_behave_like "logging info and errors"
        end
      end
    end
  end
end
