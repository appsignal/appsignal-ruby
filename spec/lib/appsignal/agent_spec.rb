require 'spec_helper'

class PostProcessingException < Exception
end

describe Appsignal::Agent do
  before :all do
    start_agent
  end

  let(:transaction) { regular_transaction }

  its(:active?) { should be_true }

  context "pid" do
    its(:master_pid) { should == Process.pid }
    its(:pid) { should == Process.pid }
  end

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
        subject.stub(:aggregator => double(:has_transactions? => true))
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

    context "with revision" do
      around do |sample|
        ENV['APP_REVISION'] = 'abc'
        sample.run
        ENV['APP_REVISION'] = nil
      end

      it "should set the revision" do
        subject.start_thread
        expect( subject.revision ).to eql 'abc'
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

  describe "#subscribe" do
    it "should have set the appsignal subscriber" do
      if defined? ActiveSupport::Notifications::Fanout::Subscribers::Timed
        # ActiveSupport 4
        subject.subscriber.should be_a ActiveSupport::Notifications::Fanout::Subscribers::Timed
      else
        # ActiveSupport 3
        subject.subscriber.should be_a ActiveSupport::Notifications::Fanout::Subscriber
      end
    end

    context "handling events" do
      before :each do
        # Unsubscribe previous notification subscribers
        ActiveSupport::Notifications.notifier.instance_variable_get(:@subscribers).
          reject { |sub| sub.instance_variable_get(:@pattern).is_a? String }.
          each { |sub| ActiveSupport::Notifications.unsubscribe(sub) }
        # And re-subscribe with just one subscriber
        Appsignal.agent.subscribe

        Appsignal::Transaction.create('123', {})
      end

      it "should should not listen to events that start with a bang" do
        Appsignal::Transaction.current.should_not_receive(:add_event)

        ActiveSupport::Notifications.instrument '!render_template'
      end

      it "should add a normal event" do
        Appsignal::Transaction.current.should_not_receive(:set_process_action_event)
        Appsignal::Transaction.current.should_receive(:add_event).with(
          kind_of(ActiveSupport::Notifications::Event)
        ).at_least(:once)

        ActiveSupport::Notifications.instrument 'render_template'
      end

      it "should add and set a process action event" do
        Appsignal::Transaction.current.should_receive(:set_process_action_event).with(
          kind_of(ActiveSupport::Notifications::Event)
        ).at_least(:once)
        Appsignal::Transaction.current.should_receive(:add_event).with(
          kind_of(ActiveSupport::Notifications::Event)
        ).at_least(:once)

        ActiveSupport::Notifications.instrument 'process_action.rack'
      end

      it "should add and set a perform job event" do
        Appsignal::Transaction.current.should_receive(:set_perform_job_event).with(
          kind_of(ActiveSupport::Notifications::Event)
        ).at_least(:once)
        Appsignal::Transaction.current.should_receive(:add_event).with(
          kind_of(ActiveSupport::Notifications::Event)
        ).at_least(:once)

        ActiveSupport::Notifications.instrument 'perform_job.processor'
      end
    end

    describe "#unsubscribe" do
      before :each do
        Appsignal.agent.unsubscribe
      end

      it "should not have a subscriber" do
        Appsignal.agent.subscriber.should be_nil
      end

      it "should add a normal event" do
        Appsignal::Transaction.current.should_not_receive(:add_event)

        ActiveSupport::Notifications.instrument 'moo'
      end
    end
  end

  describe "#resubscribe" do
    it "should stop and start the thread" do
      subject.should_receive(:unsubscribe)
      subject.should_receive(:subscribe)
    end

    after { subject.resubscribe }
  end

  describe "#enqueue" do
    let(:transaction) { double(:action => 'test#test', :request_id => 'id') }
    subject { Appsignal.agent }

    it "forwards to the aggregator" do
      subject.aggregator.should respond_to(:add)
      subject.aggregator.should_receive(:add).with(transaction)
      subject.should_not_receive(:forked!)
    end

    context "if we have been forked" do
      before { Process.stub(:pid => 9000000002) }

      it "should call forked!" do
        subject.aggregator.should_receive(:add).with(transaction)
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

        it "should set the transmission state to successful" do
          subject.send_aggregators
          expect( subject.transmission_successful ).to be_true
        end
      end

      context "when failed to sent" do
        before { subject.stub(:handle_result => false) }

        it "should remove only successfully sent item from the queue" do
          expect {
            subject.send_aggregators
          }.to_not change(subject, :aggregator_queue)
        end

        it "should set the transmission state to unsuccessful" do
          subject.send_aggregators
          expect( subject.transmission_successful ).to be_false
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

        it "should set the transmission state to unsuccessful" do
          subject.send_aggregators
          expect( subject.transmission_successful ).to be_false
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

  describe "#forked!" do
    subject { Appsignal.agent }

    it "should set active to true, create a new aggregator, set the new pid and restart the thread" do
      master_pid = subject.master_pid
      subject.pid.should == master_pid

      Process.stub(:pid => 9000000001)
      subject.active = false
      subject.should_receive(:resubscribe)
      subject.should_receive(:restart_thread)
      previous_aggregator = subject.aggregator

      subject.forked!

      subject.active?.should be_true

      subject.aggregator.should_not == previous_aggregator
      subject.aggregator.should be_a Appsignal::Aggregator

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
      subject.instance_variable_set(:@transmission_successful, true)

      subject.should_receive(:send_queue)

      subject.shutdown(true, nil)
    end

    it "should only shutdown if the queue is not be sent" do
      subject.instance_variable_set(:@transmission_successful, false)
      subject.should_not_receive(:send_queue)

      subject.shutdown(false, nil)
    end
  end

  describe '#handle_result' do
    before { subject.aggregator.add(transaction) }
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
