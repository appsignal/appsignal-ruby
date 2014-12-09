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

    its(:aggregator) { should be_instance_of(Appsignal::Agent::Aggregator) }
    its(:transmitter) { should be_instance_of(Appsignal::Transmitter) }
    its(:aggregator_queue) { should == [] }
    its(:added_event_digests) { should == {} }
    its(:subscriber) { should be_instance_of(Appsignal::Agent::Subscriber) }
    its(:thread) { should be_instance_of(Thread) }

    its(:active?) { should be_true }
  end

  describe "#start_thread" do
    before do
      subject.thread = nil
      subject.stub(:sleep_time => 0.1)
    end

    it "should truncate the aggregator queue" do
      subject.should_receive(:truncate_aggregator_queue).at_least(1).times
      subject.start_thread
      sleep 1
    end

    context "without transactions" do
      it "should start and run a background thread" do
        subject.should_not_receive(:send_queue)

        subject.start_thread

        subject.thread.should be_a(Thread)
        subject.thread.should be_alive
      end
    end

    context "with transactions" do
      before do
        subject.aggregator.should respond_to(:any?)
        subject.aggregator.stub(:any? => true)
      end

      it "should send the queue and sleep" do
        subject.should_receive(:send_queue).at_least(:twice)

        subject.start_thread
        sleep 2
      end
    end

    context "with items in the aggregator queue" do
      before do
        subject.aggregator_queue.stub(:any? => true)
      end

      it "should send the queue and sleep" do
        subject.should_receive(:send_queue).at_least(:twice)

        subject.start_thread
        sleep 2
      end
    end

    context "when an exception occurs in the thread" do
      before do
        aggregator = double
        aggregator.stub(:has_transactions?).and_raise(
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

  describe "#enqueue" do
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

    after { subject.enqueue(transaction) }
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

  describe "#send_queue" do
    it "adds aggregator to queue" do
      subject.aggregator.stub(:post_processed_queue! => :foo)
      subject.should_receive(:add_to_aggregator_queue).with(:foo)
    end

    it "sends aggregators" do
      subject.should_receive(:send_aggregators)
    end

    it "handle exceptions in post processing" do
      subject.aggregator.stub(:post_processed_queue!).and_raise(
        PostProcessingException.new('Message')
      )

      Appsignal.logger.should_receive(:error).
        with(kind_of(String)).
        once
    end

    it "handles exceptions in transmit" do
      subject.stub(:send_aggregators).and_raise(
        Exception.new('Message')
      )

      Appsignal.logger.should_receive(:error).
        with(kind_of(String)).
        once
    end

    after { subject.send_queue }
  end

  describe "#send_aggregators" do
    let(:aggregator_hash) { double }
    before { subject.add_to_aggregator_queue(aggregator_hash) }

    context "sending aggreagotor hashes" do
      it "sends each item in the aggregators_to_be_sent array" do
        subject.transmitter.should_receive(:transmit).with(aggregator_hash)
      end

      it "handles the return code" do
        subject.transmitter.stub(:transmit => '200')
        subject.should_receive(:handle_result).with('200')
      end

      after { subject.send_aggregators }
    end

    context "managing the queue" do
      before { subject.transmitter.stub(:transmit => '200') }

      context "when successfully sent" do
        before { subject.stub(:handle_result => true) }

        it "should remove only successfully sent item from the queue" do
          expect {
            subject.send_aggregators
          }.to change(subject, :aggregator_queue).from([aggregator_hash]).to([])
        end
      end

      context "when failed to sent" do
        before { subject.stub(:handle_result => false) }

        it "should remove only successfully sent item from the queue" do
          expect {
            subject.send_aggregators
          }.to_not change(subject, :aggregator_queue)
        end
      end

      context "when an exception related to connection problems occurred during sending" do
        before { subject.stub(:transmitter).and_raise(OpenSSL::SSL::SSLError.new) }

        it "should remove only successfully sent item from the queue" do
          Appsignal.logger.should_receive(:error).
            with(kind_of(String)).
            once

          expect {
            subject.send_aggregators
          }.to_not change(subject, :aggregator_queue)
        end

      end
    end
  end

  describe "#truncate_aggregator_queue" do
    before do
      5.times { |i| subject.add_to_aggregator_queue(i) }
    end

    it "should truncate the queue to the given limit" do
      expect {
        subject.truncate_aggregator_queue(2)
      }.to change(subject, :aggregator_queue).from([4, 3, 2, 1, 0]).to([4,3])
    end

    it "should log this event as an error" do
      Appsignal.logger.should_receive(:error).
        with('Aggregator queue to large, removing items').
        once

      subject.truncate_aggregator_queue(2)
    end
  end

  describe "#clear_queue" do
    it "starts a new aggregator" do
      Appsignal::Agent::Aggregator.should_receive(:new).twice # once on start, once on clear
    end

    after { subject.clear_queue }
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

    it "should send the queue and shut down if the queue is to be sent" do
      subject.should_receive(:send_queue)

      subject.shutdown(true, nil)
    end

    it "should only shutdown if the queue is not be sent" do
      subject.should_not_receive(:send_queue)

      subject.shutdown(false, nil)
    end
  end

  describe '#handle_result' do
    before { subject.aggregator.add_transaction(transaction) }
    before { subject.instance_variable_set(:@sleep_time, 3.0) }

    context "good responses" do
      before { subject.send(:handle_result, code) }

      context "with 200" do
        let(:code) { '200' }

        its(:sleep_time) { should == 3.0 }

        it "does not log the event" do
          Appsignal.logger.should_not_receive(:error)
        end
      end

      context "with 420" do
        let(:code) { '420' }

        its(:sleep_time) { should == 4.5 }
      end

      context "with 413" do
        let(:code) { '413' }

        its(:sleep_time) { should == 2.0 }
      end
    end

    context "bad responses" do
      context "with 429" do
        let(:code) { '429' }

        it "calls a stop to logging" do
          subject.should_receive(:shutdown)
        end
      end

      context "with 406" do
        let(:code) { '406' }

        it "calls a stop to logging" do
          subject.should_receive(:shutdown)
        end
      end

      context "with 402" do
        let(:code) { '402' }

        it "calls a stop to logging" do
          subject.should_receive(:shutdown)
        end
      end

      context "with 401" do
        let(:code) { '401' }

        it "calls a stop to logging" do
          subject.should_receive(:shutdown)
        end
      end

      context "any other response" do
        let(:code) { 'any other response' }

        it "logs the event" do
          Appsignal.logger.should_receive(:error)
        end
      end

      after { subject.send(:handle_result, code) }
    end

    context "return values" do
      %w( 200 420 413 429 406 402 401 ).each do |code|
        it "should return true for '#{code}'" do
          subject.send(:handle_result, code).should be_true
        end
      end

      %w( 500 502 ).each do |code|
        it "should return false for '#{code}'" do
          subject.send(:handle_result, code).should be_false
        end
      end
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
