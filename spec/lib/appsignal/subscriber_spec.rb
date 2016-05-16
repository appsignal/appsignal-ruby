require 'spec_helper'

describe Appsignal::Subscriber do
  before :all do
    start_agent
  end

  before do
    ActiveSupport::Notifications.notifier.instance_variable_get(:@subscribers).clear
    Thread.current[:appsignal_transaction] = nil
  end

  let(:subscriber) { Appsignal::Subscriber.new }
  subject { subscriber }

  context "initialization" do
    before do
      subject
    end

    it "should be in the subscriber list" do
      ActiveSupport::Notifications.notifier.instance_variable_get(:@subscribers).select do |s|
        s.instance_variable_get(:@delegate).is_a?(Appsignal::Subscriber)
      end.count.should == 1
    end
  end

  context "subscriptions" do
    describe "subscribe" do
      it "should subscribe" do
        subject.subscribe
        subject.as_subscriber.should_not be_nil

        ActiveSupport::Notifications.notifier.instance_variable_get(:@subscribers).select do |s|
          s.instance_variable_get(:@delegate).is_a?(Appsignal::Subscriber)
        end.count.should == 2
      end
    end

    describe "#unsubscribe" do
      it "should unsubscribe" do
        subject.unsubscribe
        subject.as_subscriber.should be_nil

        ActiveSupport::Notifications.notifier.instance_variable_get(:@subscribers).select do |s|
          s.instance_variable_get(:@delegate).is_a?(Appsignal::Subscriber)
        end.count.should == 0
      end
    end

    describe "#resubscribe" do
      it "should unsubscribe and subscribe" do
        subject.resubscribe
        subject.as_subscriber.should_not be_nil

        ActiveSupport::Notifications.notifier.instance_variable_get(:@subscribers).select do |s|
          s.instance_variable_get(:@delegate).is_a?(Appsignal::Subscriber)
        end.count.should == 1
      end
    end
  end

  describe "#publish" do
    it "should exist" do
      lambda {
        subject.publish('name', '')
      }.should_not raise_error
    end
  end

  context "handling events using #start and #finish" do
    before do
      subscriber
    end

    it "should should not listen to events that start with a bang" do
      subject.should_not_receive(:start)
      subject.should_not_receive(:finish)

      ActiveSupport::Notifications.instrument '!render_template'
    end

    it "should not record events when there is no current transaction" do
      Appsignal::Extension.should_not_receive(:start_event)
      Appsignal::Extension.should_not_receive(:finish_event)

      lambda {
        ActiveSupport::Notifications.instrument 'something'
      }.should_not raise_error
    end

    context "with a current transaction" do
      let(:transaction) { Appsignal::Transaction.current }

      before do
        Appsignal::Transaction.create('request-id', Appsignal::Transaction::HTTP_REQUEST, {})
      end

      it "should call native start and finish event for every event" do
        transaction.should_receive(:start_event).exactly(4).times
        transaction.should_receive(:finish_event).with('one', nil, nil, nil).once
        transaction.should_receive(:finish_event).with('two', nil, nil, nil).once
        transaction.should_receive(:finish_event).with('two.three', nil, nil, nil).once
        transaction.should_receive(:finish_event).with('one.three', nil, nil, nil).once

        ActiveSupport::Notifications.instrument('one') do
          ActiveSupport::Notifications.instrument('two') do
            ActiveSupport::Notifications.instrument('one.three') do
            end
            ActiveSupport::Notifications.instrument('two.three') do
            end
          end
        end
      end

      it "should call finish with title and body if there is a formatter" do
        transaction.should_receive(:start_event).once
        transaction.should_receive(:finish_event).with(
          'request.net_http',
          'GET http://www.google.com',
          nil,
          nil
        ).once

        ActiveSupport::Notifications.instrument(
          'request.net_http',
          :protocol => 'http',
          :domain   => 'www.google.com',
          :method   => 'GET'
        )
      end

      it "should call finish with title, body and body format if there is a formatter that returns it" do
        transaction.should_receive(:start_event).once
        transaction.should_receive(:finish_event).with(
          'sql.active_record',
          'Something load',
          'SELECT * FROM something',
          1
        ).once

        ActiveSupport::Notifications.instrument(
          'sql.active_record',
          :name => 'Something load',
          :sql  => 'SELECT * FROM something'
        )
      end

      context "when paused" do
        before { transaction.pause! }

        it "should add no events" do
          Appsignal::Extension.should_not_receive(:start_event)
          Appsignal::Extension.should_not_receive(:finish_event)

          ActiveSupport::Notifications.instrument 'sql.active_record'
        end
      end
    end
  end
end
