require 'spec_helper'

class PostProcessingException < Exception
end

describe Appsignal::Agent do
  before :all do
    start_agent
  end

  let(:transaction) { regular_transaction }

  context "initialization" do
    describe "#sleep_time" do
      subject { Appsignal::Agent.new.sleep_time }

      it { should == 60 }

      context "for development" do
        before do
          Appsignal.config.stub(:env => 'development')
        end

        it { should == 10 }
      end
    end

    context "pid" do
      its(:master_pid) { should == Process.pid }
      its(:pid) { should == Process.pid }
    end

    its(:added_event_digests) { should == {} }
    its(:aggregator) { should be_instance_of(Appsignal::Agent::Aggregator) }
    its(:aggregator_transmitter) { should be_instance_of(Appsignal::Agent::AggregatorTransmitter) }
    its(:subscriber) { should be_instance_of(Appsignal::Agent::Subscriber) }
    its(:thread) { should be_instance_of(Thread) }

    its(:active?) { should be_true }
  end

  describe "#start_thread" do
    before do
      subject.thread = nil
      subject.stub(:sleep_time => 0.1)
    end

    it "should call the replace_aggregator_and_transmit every sleep time seconds" do
      subject.should_receive(:replace_aggregator_and_transmit).at_least(:twice)

      subject.start_thread
      sleep 2
    end

    context "when an exception occurs in the thread" do
      before do
        aggregator = double
        aggregator.stub(:any?).and_raise(
          RuntimeError.new('error')
        )
        subject.stub(:aggregator => aggregator)
      end

      it "should log the error" do
        Appsignal.logger.should_receive(:error).
          with(kind_of(String)).
          once

        subject.start_thread
        sleep 1
      end
    end
  end

  describe "#restart_thread" do
    it "should stop and start the thread" do
      subject.should_receive(:stop_thread)
      subject.should_receive(:start_thread)
    end

    after { subject.restart_thread }
  end

  describe "#stop_thread" do
    context "if there is no thread" do
      before { subject.thread = nil }

      it "should not do anything" do
        Thread.should_not_receive(:kill)
      end
    end

    context "if there is an inactive thread" do
      before do
        Thread.kill(subject.thread)
        sleep 0.1 # We need to wait for the thread to exit
      end

      it "should start a thread" do
        Thread.should_not_receive(:kill)
      end
    end

    context "if there is an active thread" do
      it "should kill the current thread " do
        Thread.should_receive(:kill)
      end
    end

    after { subject.stop_thread }
  end

  describe "#add_transaction" do
    let(:transaction) { double(:action => 'test#test', :request_id => 'id') }
    subject { Appsignal.agent }

    it "forwards to the aggregator" do
      subject.aggregator.should respond_to(:add_transaction)
      subject.aggregator.should_receive(:add_transaction).with(transaction)
      subject.should_not_receive(:forked!)
    end

    context "if we have been forked" do
      before { Process.stub(:pid => 9000000002) }

      it "should call forked!" do
        subject.aggregator.should_receive(:add_transaction).with(transaction)
        subject.should_receive(:forked!)
      end
    end

    context "with ignored action" do
      before { Appsignal.stub(:is_ignored_action? => true) }

      it "should not add item to queue" do
        subject.aggregator.should_not_receive(:add)
      end
    end

    after { subject.add_transaction(transaction) }
  end

  describe "#add_event_details" do
    it "should add event details" do
      subject.aggregator.should_receive(:add_event_details).with('digest', 'name', 'title', 'body')

      subject.add_event_details('digest', 'name', 'title', 'body')
    end

    context "when there are details present" do
      before do
        subject.aggregator.should_receive(:add_event_details).once
        subject.add_event_details('digest', 'name', 'title', 'body')
      end

      it "should not add the event details again" do
        subject.aggregator.should_not_receive(:add_event_details)

        subject.add_event_details('digest', 'name', 'title', 'body')
      end

      it "should add event details for a different event" do
        subject.aggregator.should_receive(:add_event_details).with('digest2', 'name', 'title', 'body')

        subject.add_event_details('digest2', 'name', 'title', 'body')
      end
    end
  end

  describe "#replace_aggregator_and_transmit" do
    it "adds the aggregator to the transmitter if it has content" do
      subject.aggregator.stub(:any? => true)
      subject.aggregator_transmitter.should_receive(:add).with(subject.aggregator)
    end

    it "does not add the aggregator to the transmitter if it has no content" do
      subject.aggregator_transmitter.should_not_receive(:add)
    end

    it "calls transmit" do
      subject.aggregator_transmitter.should_receive(:transmit)
    end

    it "calls transmit" do
      subject.aggregator_transmitter.should_receive(:truncate)
    end

    it "handles exceptions" do
      subject.aggregator_transmitter.stub(:transmit).and_raise(
        Exception.new('Message')
      )

      Appsignal.logger.should_receive(:error).
        with(kind_of(String)).
        once
    end

    after { subject.replace_aggregator_and_transmit }
  end

  describe "#forked!" do
    subject { Appsignal.agent }

    it "should set active to true, create a new aggregator, set the new pid and restart the thread" do
      master_pid = subject.master_pid
      subject.pid.should == master_pid

      Process.stub(:pid => 9000000001)
      subject.active = false
      subject.subscriber.should_receive(:resubscribe)
      subject.should_receive(:restart_thread)
      previous_aggregator = subject.aggregator

      subject.forked!

      subject.active?.should be_true

      subject.aggregator.should_not == previous_aggregator
      subject.aggregator.should be_a Appsignal::Agent::Aggregator

      subject.master_pid.should == master_pid
      subject.pid.should == 9000000001
    end
  end

  describe "#shutdown" do
    before do
      ActiveSupport::Notifications.should_receive(:unsubscribe).with(subject.subscriber)
      Thread.should_receive(:kill).with(subject.thread)
    end

    it "should not be active anymore after shutting down" do
      subject.shutdown
      subject.active?.should be_false
    end

    it "should log the reason for shutting down" do
      Appsignal.logger.should_receive(:info).with('Shutting down agent (shutting down)')
      subject.shutdown(false, 'shutting down')
    end

    it "should transmit and shut down if final transmission is to take place" do
      subject.should_receive(:replace_aggregator_and_transmit)

      subject.shutdown(true, nil)
    end

    it "should only shutdown if no final transmission is to take place" do
      subject.should_not_receive(:replace_aggregator_and_transmit)

      subject.shutdown(false, nil)
    end
  end

  context "when inactive" do
    before { Appsignal.config.stub(:active? => false) }

    it "should not start a thread" do
      Thread.should_not_receive(:new)
    end

    after { Appsignal::Agent.new }
  end
end
