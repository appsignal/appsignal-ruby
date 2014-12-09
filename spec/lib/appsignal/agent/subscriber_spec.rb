require 'spec_helper'

# We want to get at this info the test
class ActiveSupport::Notifications::Fanout
  attr_reader :subscribers
  class Subscribers::Evented
    attr_reader :delegate
  end
end

describe Appsignal::Agent::Subscriber do
  before :all do
    start_agent
  end

  let(:subscriber) { Appsignal.agent.subscriber }
  subject { subscriber }

  context "initialization" do
    its(:agent) { should == Appsignal.agent }

    it "should be in the subscriber list" do
      ActiveSupport::Notifications.notifier.subscribers.first.delegate.should be_a(Appsignal::Agent::Subscriber)
    end
  end

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
      lambda {
        ActiveSupport::Notifications.instrument 'something'
      }.should_not raise_error
    end

    context "with a current transaction and frozen time" do
      let(:transaction) { Appsignal::Transaction.current }
      let(:start_time) { Time.at(1418660000.0) }

      before do
        Timecop.freeze(start_time)
        Appsignal::Transaction.create('request-id', {})
      end

      after do
        Thread.current[:appsignal_transaction] = nil
        Timecop.return
      end

      context "with some events" do
        before do
          current_time = start_time
          ActiveSupport::Notifications.instrument('one') do
            current_time = advance_frozen_time(current_time, 0.1)
            ActiveSupport::Notifications.instrument('two') do
              current_time = advance_frozen_time(current_time, 0.4)
              ActiveSupport::Notifications.instrument('one.three') do
                current_time = advance_frozen_time(current_time, 0.1)
              end
              ActiveSupport::Notifications.instrument('two.three') do
                current_time = advance_frozen_time(current_time, 0.1)
              end
            end
          end
        end

        subject { transaction.events }

        it { should have(4).items }

        context "event one" do
          subject { transaction.events[3] }

          its([:digest])         { should be_nil }
          its([:name])           { should == 'one' }
          its([:started])        { should == 1418660000.0 }
          its([:duration])       { should be_within(0.02).of(0.7) }
          its([:child_duration]) { should be_within(0.02).of(0.6) }
          its([:level])          { should == 0 }
        end

        context "event two" do
          subject { transaction.events[2] }

          its([:digest])         { should be_nil }
          its([:name])           { should == 'two' }
          its([:started])        { should == 1418660000.1 }
          its([:duration])       { should be_within(0.02).of(0.6) }
          its([:child_duration]) { should be_within(0.02).of(0.2) }
          its([:level])          { should == 1 }
        end

        context "event two.three" do
          subject { transaction.events[1] }

          its([:digest])         { should be_nil }
          its([:name])           { should == 'two.three' }
          its([:started])        { should == 1418660000.6 }
          its([:duration])       { should be_within(0.02).of(0.1) }
          its([:child_duration]) { should == 0.0 }
          its([:level])          { should == 2 }
        end

        context "event one.three" do
          subject { transaction.events[0] }

          its([:digest])         { should be_nil }
          its([:name])           { should == 'one.three' }
          its([:started])        { should == 1418660000.5 }
          its([:duration])       { should be_within(0.02).of(0.1) }
          its([:child_duration]) { should == 0.0 }
          its([:level])          { should == 2 }
        end
      end

      context "with an event with a formatter" do
        before do
          3.times do
            ActiveSupport::Notifications.instrument(
              'request.net_http',
              :url => 'http://www.google.com',
              :method => 'GET'
            )
          end
        end

        subject { transaction.events }

        it { should have(3).items }

        context "first event" do
          subject { transaction.events.first }

          its([:name]) { should == 'request.net_http' }
          its([:digest]) { should == '41771902b526b4a972581ce2a606fb39' }
        end

        context "event details" do
          subject { Appsignal.agent.aggregator.event_details }

          context "first" do
            subject { Appsignal.agent.aggregator.event_details.first }

            its([:digest]) { should == '41771902b526b4a972581ce2a606fb39' }
            its([:name])   { should == 'request.net_http' }
            its([:title])  { should == 'GET http://www.google.com' }
            its([:body])   { should be_nil }
          end
        end
      end

      it "should not record events when paused" do
        ActiveSupport::Notifications.instrument 'outside'
        Appsignal.without_instrumentation do
          ActiveSupport::Notifications.instrument 'inside'
        end

        transaction.events.should have(1).item
        transaction.events.first[:name].should == 'outside'
      end

      pending "should do something with process action event"

      pending "should do something with perform job event"
    end
  end
end
