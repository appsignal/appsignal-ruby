require 'spec_helper'

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

    it "handles exceptions in transmit" do
      subject.transmitter.stub(:transmit).and_raise(Exception.new)
      subject.should_receive(:stop_logging)
      Appsignal.logger.should_receive(:error).
        with('Exception while communicating with AppSignal: Exception')
    end

    after { subject.send_queue }
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
          subject.should_receive :stop_logging
        end
      end

      context "with 406" do
        let(:code) { '406' }

        it "calls a stop to logging" do
          subject.should_receive :stop_logging
        end
      end

      context "with 402" do
        let(:code) { '402' }

        it "calls a stop to logging" do
          subject.should_receive :stop_logging
        end
      end

      context "with 401" do
        let(:code) { '401' }

        it "calls a stop to logging" do
          subject.should_receive :stop_logging
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

  describe "#stop_logging" do
    it "does not raise exceptions" do
      expect { subject.send :stop_logging }.not_to raise_error
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
