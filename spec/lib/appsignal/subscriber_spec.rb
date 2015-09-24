require 'spec_helper'

describe Appsignal::Subscriber do
  before :all do
    start_agent
  end

  before do
    Thread.current[:appsignal_transaction] = nil
  end

  let(:subscriber) { Appsignal.subscriber }
  subject { subscriber }

  context "initialization" do
    it "should be in the subscriber list" do
      ActiveSupport::Notifications.notifier.instance_variable_get(:@subscribers).select do |s|
        s.instance_variable_get(:@delegate).is_a?(Appsignal::Subscriber)
      end.count == 1
    end
  end

  context "subscriptions" do
    describe "subscribe" do
      it "should subscribe" do
        ActiveSupport::Notifications.should_receive(:subscribe).with(/^[^!]/, subject).at_least(:once)

        subject.subscribe
      end
    end

    describe "#unsubscribe" do
      it "should unsubscribe" do
        ActiveSupport::Notifications.should_receive(:unsubscribe).with(subject).at_least(:once)

        subject.unsubscribe
      end
    end

    describe "#resubscribe" do
      it "should unsubscribe and subscribe" do
        subject.should_receive(:unsubscribe).at_least(:once)
        subject.should_receive(:subscribe)

        subject.resubscribe
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
        Appsignal::Extension.should_receive(:start_event).exactly(4).times
        Appsignal::Extension.should_receive(:finish_event).with(kind_of(Integer), 'one', '', '').once
        Appsignal::Extension.should_receive(:finish_event).with(kind_of(Integer), 'two', '', '').once
        Appsignal::Extension.should_receive(:finish_event).with(kind_of(Integer), 'two.three', '', '').once
        Appsignal::Extension.should_receive(:finish_event).with(kind_of(Integer), 'one.three', '', '').once

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
          Appsignal::Extension.should_receive(:start_event).once
          Appsignal::Extension.should_receive(:finish_event).with(
            kind_of(Integer),
            'request.net_http',
            'GET http://www.google.com',
            ''
          ).once

          ActiveSupport::Notifications.instrument(
            'request.net_http',
            :protocol => 'http',
            :domain   => 'www.google.com',
            :method   => 'GET'
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
