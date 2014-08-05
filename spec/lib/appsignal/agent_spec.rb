require 'spec_helper'

class PostProcessingException < Exception
end

describe Appsignal::Agent do
  before :all do
    start_agent
  end

  let(:transaction) { regular_transaction }

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
    before { subject.thread = nil }

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
        subject.stub(
          :aggregator => double(:has_transactions? => true),
          :sleep_time => 0.01
        )
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
        subject.stub(
          :aggregator => aggregator,
          :sleep_time => 0.1
        )
      end

      it "should log the error" do
        Appsignal.logger.should_receive(:error).
          with("RuntimeError in agent thread: 'error'").
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

      context "when paused" do
        it "should add a normal event" do
          Appsignal::Transaction.current.should_not_receive(:add_event)

          Appsignal.without_instrumentation do
            ActiveSupport::Notifications.instrument 'moo'
          end
        end
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
    subject { Appsignal.agent }

    it "forwards to the aggregator" do
      subject.aggregator.should respond_to(:add)
      subject.aggregator.should_receive(:add).with(:foo)
      subject.should_not_receive(:forked!)
    end

    context "if we have been forked" do
      before { Process.stub(:pid => 9000000002) }

      it "should call forked!" do
        subject.aggregator.should_receive(:add).with(:foo)
        subject.should_receive(:forked!)
      end
    end

    after { subject.enqueue(:foo) }
  end

  describe "#send_queue" do
    it "transmits" do
      subject.aggregator.stub(:post_processed_queue! => :foo)
      subject.transmitter.should_receive(:transmit).with(:foo)
    end

    it "handles the return code" do
      subject.transmitter.stub(:transmit => '200')
      subject.should_receive(:handle_result).with('200')
    end

    it "handle exceptions in post processing" do
      subject.aggregator.stub(:post_processed_queue!).and_raise(
        PostProcessingException.new('Message')
      )

      Appsignal.logger.should_receive(:error).
        with('PostProcessingException while sending queue: Message').
        once
      Appsignal.logger.should_receive(:error).
        with(kind_of(String)).
        once
    end

    it "handles exceptions in transmit" do
      subject.transmitter.stub(:transmit).and_raise(
        Exception.new('Message')
      )

      Appsignal.logger.should_receive(:error).
        with('Exception while sending queue: Message').
        once
      Appsignal.logger.should_receive(:error).
        with(kind_of(String)).
        once
    end

    after { subject.send_queue }
  end

  describe "#clear_queue" do
    it "starts a new aggregator" do
      Appsignal::Aggregator.should_receive(:new).twice # once on start, once on clear
    end

    after { subject.clear_queue }
  end

  describe "#forked!" do
    subject { Appsignal.agent }

    it "should create a new aggregator, set the new pid and restart the thread" do
      master_pid = subject.master_pid
      subject.pid.should == master_pid

      Process.stub(:pid => 9000000001)
      subject.should_receive(:resubscribe)
      subject.should_receive(:restart_thread)
      previous_aggregator = subject.aggregator

      subject.forked!

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

    context "when not sending the current queue" do
      it "should log the reason for shutting down" do
          Appsignal.logger.should_receive(:info).with('Shutting down agent (shutting down)')
          subject.shutdown(false, 'shutting down')
      end

      context "with an empty queue" do
        it "should shutdown" do
          subject.shutdown
        end
      end

      context "with a queue with transactions" do
        it "should shutdown" do
          subject.enqueue(slow_transaction)
          subject.should_not_receive(:send_queue)

          subject.shutdown
        end
      end
    end

    context "when the queue is to be sent" do
      context "with an empty queue" do
        it "should shutdown" do
          subject.should_not_receive(:send_queue)

          subject.shutdown(true, nil)
        end
      end

      context "with a queue with transactions" do
        it "should send the queue and shutdown" do
          subject.enqueue(slow_transaction)
          subject.should_receive(:send_queue)

          subject.shutdown(true, nil)
        end
      end
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

        it "clears the queue" do
          subject.should_receive(:clear_queue)
        end
      end

      after { subject.send(:handle_result, code) }
    end
  end

  context "when inactive" do
    before { Appsignal.stub(:active? => false) }

    it "should not start a thread" do
      Thread.should_not_receive(:new)
    end

    after { Appsignal::Agent.new }
  end
end
