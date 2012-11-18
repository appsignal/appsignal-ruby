require 'spec_helper'
require 'appsignal/instrumentation/mongo'

describe "Appsignal::MongoInstrumentation" do
  let(:log) { StringIO.new }
  let(:logger) { Logger.new(log) }

  context "without mongo required" do
    it "should do nothing" do
      Appsignal::MongoInstrumentation.setup(logger)
      log.string.should be_empty
    end

    context "with mongo required" do
      before :all do
        silence_warnings { require 'mongo' }
        Appsignal::MongoInstrumentation.setup(logger)
        class MockMongoLogger
          include Mongo::Logging
        end
        @mongo_logger = MockMongoLogger.new
      end

      it "should say it's instrumenting in the log" do
        log.string.should include 'Adding instrumentation to Mongo::Logging'
      end

      it "should have both an instrument and an instrument_without_notification method" do
        @mongo_logger.respond_to?(:instrument).should be_true
        @mongo_logger.respond_to?(:instrument_without_notification).should be_true
      end

      it "should add a notification when instrument is called" do
        ActiveSupport::Notifications.should_receive(:instrument).with(
          'query.mongodb',
          :query => {:method => 'method_name', :payload => true}
        )
        @mongo_logger.instrument('method_name', :payload => true)
      end

      it "should call the original instrument method after adding a notification" do
        @mongo_logger.should_receive(:instrument_without_notification).with(
          'method_name',
          :payload => true
        )
        @mongo_logger.instrument('method_name', :payload => true)
      end
    end
  end
end
