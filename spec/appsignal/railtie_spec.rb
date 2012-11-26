require 'spec_helper'
require 'action_controller/railtie'
require 'appsignal/railtie'

describe Appsignal::Railtie do

  before(:all) { MyApp::Application.initialize! }

  it "should have set the appsignal subscriber" do
    Appsignal.subscriber.
      should be_a ActiveSupport::Notifications::Fanout::Subscriber
  end

  it "should have added the middleware for exceptions" do
    MyApp::Application.middleware.to_a.should include Appsignal::Middleware
  end

  context "non action_controller event" do
    it "should call add_event for non action_controller event" do
      current = stub
      current.should_receive(:add_event)
      Appsignal::Transaction.should_receive(:current).twice.
        and_return(current)
    end

    after { ActiveSupport::Notifications.instrument 'query.mongoid' }
  end

  context "action_controller event" do
    it "should call set_log_entry for action_controller event" do
      current = stub
      current.should_receive(:set_log_entry)
      current.should_receive(:add_event)
      Appsignal::Transaction.should_receive(:current).exactly(3).times.
        and_return(current)
    end

    after do
      ActiveSupport::Notifications.
        instrument 'process_action.action_controller'
    end
  end

  context "event that starts with a bang" do
    it "should not be processed" do
      Appsignal::Transaction.should_not_receive(:current)
    end

    after do
      ActiveSupport::Notifications.
        instrument '!render_template'
    end
  end
end
