require 'spec_helper'

describe Appsignal::Agent do
  let(:event) { stub(:name => 'event') }

  describe '#add_to_queue' do
    it 'should add the event to the queue' do
      expect {
        subject.add_to_queue(event)
      }.to change(subject, :queue).to([event])
    end
  end

  describe "#send_queue" do
    it "transmits" do
      subject.stub(:queue => 'foo')
      subject.transmitter.should_receive(:transmit).with(:log_entries => 'foo')
    end

    it "handles the return code" do
      subject.transmitter.stub(:transmit => '200')
      subject.should_receive(:handle_result).with('200')
    end

    it "handles exceptions in transmit" do
      subject.transmitter.stub(:transmit).and_raise(Exception.new)
      subject.should_receive(:handle_result).with(nil)
      Appsignal.logger.should_receive(:error).with('Exception while communicating with AppSignal: Exception')
    end

    after { subject.send_queue }
  end

  describe '#handle_result' do
    before { subject.add_to_queue(event) }
    before { subject.instance_variable_set(:@sleep_time, 3.0) }

    context "good responses" do
      before { subject.handle_result(code) }

      context "with 200" do
        let(:code) { '200' }

        its(:queue) { should be_empty }
      end

      context "with 420" do
        let(:code) { '420' }

        its(:queue) { should be_empty }
        its(:sleep_time) { should == 4.5 }
      end

      context "with 413" do
        let(:code) { '413' }

        its(:queue) { should be_empty }
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

      context "with 402" do
        let(:code) { '402' }

        it "calls a stop to logging" do
          subject.should_receive :stop_logging
        end
      end

      context "any other response" do
        let(:code) { 'any other response' }

        it "calls retry_once" do
          subject.should_receive :retry_once
        end
      end

      after { subject.handle_result(code) }
    end
  end

  describe "#good_response" do
    before do
      subject.instance_variable_set(:@retry_once, false)
      subject.add_to_queue(event)
      subject.send :good_response
    end

    its(:queue) { should be_empty }

    it "allows the next request to be retried" do
      subject.instance_variable_get(:@retry_request).should be_true
    end
  end

  describe "#retry_once" do
    before do
      subject.add_to_queue(event)
      subject.send :retry_once
    end

    context "on time," do
      its(:queue) { should == [event] }

      context "two times" do
        before { subject.send :retry_once }

        its(:queue) { should be_empty }
      end
    end
  end

  describe "#stop_logging" do
    it "does not raise exceptions" do
      expect { subject.send :stop_logging }.not_to raise_error
    end
  end
end
