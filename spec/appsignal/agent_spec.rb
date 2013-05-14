require 'spec_helper'

class PostProcessingException < Exception
end

describe Appsignal::Agent do
  let(:transaction) { regular_transaction }

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

  describe "#shutdown" do
    before do
      ActiveSupport::Notifications.should_receive(:unsubscribe).with(Appsignal.subscriber)
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

      context "when we're a child process" do
        it "should shutdown" do
          subject.stub(:forked? => true)
          subject.should_not_receive(:send_queue)

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

  describe "#shutdown" do
    it "does not raise exceptions" do
      expect { subject.send(:shutdown) }.not_to raise_error
    end
  end

  describe "when inactive" do
    before { Appsignal.stub(:active? => false) }

    it "should not start a new thread" do
      Thread.should_not_receive(:new)
    end

    after { Appsignal::Agent.new }
  end
end
