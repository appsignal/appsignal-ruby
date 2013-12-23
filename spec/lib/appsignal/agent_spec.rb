require 'spec_helper'

class PostProcessingException < Exception
end

describe Appsignal::Agent do
  before :all do
    start_agent
  end

  let(:transaction) { regular_transaction }

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

    it "should start a background thread" do
      subject.start_thread

      subject.thread.should be_a(Thread)
      subject.thread.should be_alive
    end
  end

  describe "#restart_thread" do
    context "if there is no thread" do
      before { subject.thread = nil }

      it "should start a thread" do
        subject.restart_thread

        subject.thread.should be_a(Thread)
        subject.thread.should be_alive
      end
    end

    context "if there is an inactive thread" do
      before do
        Thread.kill(subject.thread)
        sleep 0.1 # We need to wait for the thread to exit
      end

      it "should start a thread" do
        subject.restart_thread

        subject.thread.should be_a(Thread)
        subject.thread.should be_alive
      end
    end

    context "if there is an active thread" do
      it "should kill the current thread and start a new one" do
        previous_thread = subject.thread
        previous_thread.should be_alive

        subject.restart_thread

        subject.thread.should be_a(Thread)
        subject.thread.should be_alive
        subject.thread.should_not == previous_thread

        sleep 0.1 # We need to wait for the thread to exit
        previous_thread.should_not be_alive
      end
    end
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
      before do
        Appsignal::Transaction.create('123', {})
      end

      it "should should not listen to events that start with a bang" do
        Appsignal::Transaction.current.should_not receive(:add_event)

        ActiveSupport::Notifications.instrument '!render_template'
      end

      it "should add a normal event" do
        Appsignal::Transaction.current.should_not receive(:set_process_action_event)
        Appsignal::Transaction.current.should receive(:add_event).with(
          kind_of(ActiveSupport::Notifications::Event)
        ).at_least(:once)

        ActiveSupport::Notifications.instrument 'render_template'
      end

      it "should add and set a process action event" do
        Appsignal::Transaction.current.should receive(:set_process_action_event).with(
          kind_of(ActiveSupport::Notifications::Event)
        ).at_least(:once)
        Appsignal::Transaction.current.should receive(:add_event).with(
          kind_of(ActiveSupport::Notifications::Event)
        ).at_least(:once)

        ActiveSupport::Notifications.instrument 'process_action.rack'
      end
    end
  end

  describe "#enqueue" do
    it "forwards to the aggregator" do
      subject.aggregator.should respond_to(:add)
      subject.aggregator.should_receive(:add).with(:foo)
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

  describe "#forked!" do
    its(:forked?) { should be_false }

    it "should create a new aggregator and restart the thread" do
      previous_aggregator = subject.aggregator
      subject.should_receive(:restart_thread)

      subject.forked!

      subject.forked?.should be_true
      subject.aggregator.should_not == previous_aggregator
      subject.aggregator.should be_a Appsignal::Aggregator
    end
  end

  describe "#shutdown" do
    before do
      ActiveSupport::Notifications.should_receive(:unsubscribe).with(subject.subscriber)
      Thread.should_receive(:kill).with(subject.thread)
    end

    context "when not sending the current queue" do
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

          subject.shutdown(true)
        end
      end

      context "with a queue with transactions" do
        it "should send the queue and shutdown" do
          subject.enqueue(slow_transaction)
          subject.should_receive(:send_queue)

          subject.shutdown(true)
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
