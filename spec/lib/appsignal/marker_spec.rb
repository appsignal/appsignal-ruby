require 'spec_helper'
require 'capistrano'

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
    let(:transmitter) { double }
    before do
      Appsignal::Transmitter.should_receive(:new).with(
        'markers', config
      ).and_return(transmitter)
    end

    it "should transmit data" do
      transmitter.should_receive(:transmit).with(
        :revision => '503ce0923ed177a3ce000005',
        :repository => 'master',
        :user => 'batman',
        :rails_env => 'production'
      )

      marker.transmit
    end

    context "logs" do
      shared_examples_for "logging info and errors" do
        it "should log status 200" do
          transmitter.should_receive(:transmit).and_return('200')

          marker.transmit

          log.string.should include('Notifying Appsignal of deploy...')
          log.string.should include('Appsignal has been notified of this deploy!')
        end

        it "should log other status" do
          transmitter.should_receive(:transmit).and_return('500')
          transmitter.should_receive(:uri).and_return('http://localhost:3000/1/markers')

          marker.transmit

          log.string.should include('Notifying Appsignal of deploy...')
          log.string.should include(
            'Something went wrong while trying to notify Appsignal: 500 at http://localhost:3000/1/markers'
          )
          log.string.should_not include(
            'Appsignal has been notified of this deploy!'
          )
        end
      end

      it_should_behave_like "logging info and errors"

      context "with a Capistrano logger" do
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
