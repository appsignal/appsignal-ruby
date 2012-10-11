require 'spec_helper'

describe Appsignal::Marker do
  let(:marker) {
    Appsignal::Marker.new({
        :revision => '503ce0923ed177a3ce000005',
        :repository => 'master',
        :user => 'batman',
        :rails_env => 'development'
      },
      'development',
      logger
    )
  }
  let(:log) {log = StringIO.new}
  let(:logger) {
    logger = Capistrano::Logger.new(:output => log)
    logger.level = Capistrano::Logger::MAX_LEVEL
    logger
  }

  context "transmit" do
    before do
      @transmitter = mock()
      Appsignal::Transmitter.should_receive(:new).
        with("http://localhost:3000/api/1", 'markers', 'abc').
        and_return(@transmitter)
    end

    it "should transmit data" do
      @transmitter.should_receive(:transmit).
        with(
          {:marker_data =>
            {
              :revision => "503ce0923ed177a3ce000005",
              :repository => "master",
              :user => "batman",
              :rails_env => "development"
            }
          }
        )

      marker.transmit
    end

    context "logs" do
      it "should log status 200" do
        @transmitter.should_receive(:transmit).and_return('200')

        marker.transmit

        log.string.should include('** Notifying Appsignal of deploy...')
        log.string.should include(
          '** Appsignal has been notified of this deploy!'
        )
      end

      it "should log other status" do
        @transmitter.should_receive(:transmit).and_return('500')

        marker.transmit

        log.string.should include('** Notifying Appsignal of deploy...')
        log.string.should include(
          '** Something went wrong while trying to notify Appsignal'
        )
        log.string.should_not include(
          '** Appsignal has been notified of this deploy!'
        )
      end
    end
  end
end
