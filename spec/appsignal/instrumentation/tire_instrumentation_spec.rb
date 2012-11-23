require 'spec_helper'
require 'appsignal/instrumentation/tire'

describe "Appsignal::TireInstrumentation" do
  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }

  context "without tire required" do
    it "should do nothing" do
      Appsignal::TireInstrumentation.setup(logger)
      log.string.should be_empty
    end

    context "with tire required, but not enabled in the config" do
      before :all do
        silence_warnings { require 'tire' }
      end

      it "should do nothing" do
        Appsignal::TireInstrumentation.setup(logger)
        log.string.should be_empty
      end

      context "with tire enabled in the config" do
        before :all do
          Appsignal.config.merge!(
            :instrumentations => {:tire => true}
          )
          Appsignal::TireInstrumentation.setup(logger)
        end
        let(:search) { Tire::Search::Search.new }

        it "should say it's instrumenting in the log" do
          log.string.should include 'Adding instrumentation to Tire::Search::Search'
        end

        it "should have both an instrument and an instrument_without_notification method" do
          search.respond_to?(:perform).should be_true
          search.respond_to?(:perform_without_notification).should be_true
        end

        it "should add a notification when perform is called" do
          ActiveSupport::Notifications.should_receive(:instrument).with(
            'query.elasticsearch',
            :params => '',
            :json => {}
          )
          search.perform
        end

        it "should call the original perform method after adding a notification" do
          search.should_receive(:perform_without_notification)
          search.perform
        end
      end
    end
  end
end
