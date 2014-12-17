require 'spec_helper'

describe Appsignal::Agent::AggregatorTransmitter do
  before :all do
    start_agent
  end

  let(:aggregator_transmitter) { Appsignal::Agent::AggregatorTransmitter.new(Appsignal.agent) }
  subject { aggregator_transmitter }
  let(:aggregator) { double(:to_json => '{}') }

  context "initialization" do
    its(:agent) { should == Appsignal.agent }
    its(:aggregators) { should == [] }
    its(:transmitter) { should be_a(Appsignal::Transmitter) }
    its(:'transmitter.action') { should == 'collect' }
  end

  describe "#add" do
    it "should add the aggregator to the queue" do
      expect {
        subject.add(aggregator)
      }.to change(subject, :aggregators).from([]).to([aggregator])
    end
  end

  describe "#transmit" do
    before { subject.add(aggregator) }

    context "transmitting aggregators" do
      it "sends each item in the aggregators array" do
        subject.transmitter.should_receive(:transmit).with('{}')
      end

      it "handles the return code" do
        subject.transmitter.stub(:transmit => '200')
        subject.should_receive(:handle_result).with('200')
      end

      after { subject.transmit }
    end

    context "managing the queue" do
      before { subject.transmitter.stub(:transmit => '200') }

      context "when successfully sent" do
        before { subject.stub(:handle_result => true) }

        it "should remove only successfully sent item from the queue" do
          expect {
            subject.transmit
          }.to change(subject, :aggregators).from([aggregator]).to([])
        end
      end

      context "when failed to sent" do
        before { subject.stub(:handle_result => false) }

        it "should remove only successfully sent item from the queue" do
          expect {
            subject.transmit
          }.to_not change(subject, :aggregators)
        end
      end

      context "when an exception related to connection problems occurred during sending" do
        before { subject.stub(:transmitter).and_raise(OpenSSL::SSL::SSLError.new) }

        it "should remove only successfully sent item from the queue" do
          Appsignal.logger.should_receive(:error).
            with(kind_of(String)).
            once

          expect {
            subject.transmit
          }.to_not change(subject, :aggregators)
        end
      end
    end
  end

  describe "#truncate" do
    before do
      5.times { |i| subject.add(i) }
    end

    it "should truncate the queue to the given limit" do
      expect {
        subject.truncate(2)
      }.to change(subject, :aggregators).from([4, 3, 2, 1, 0]).to([4,3])
    end

    it "should log this event as an error" do
      Appsignal.logger.should_receive(:error).
        with('Aggregator queue to large, removing items').
        once

      subject.truncate(2)
    end
  end

  describe "#any?" do
    subject { aggregator_transmitter.any? }

    it { should be_false }

    context "with aggregators" do
      before { aggregator_transmitter.add(aggregator) }

      it { should be_true }
    end
  end

  describe '#handle_result' do
    context "good responses" do
      before { subject.send(:handle_result, code) }

      context "with 200" do
        let(:code) { '200' }

        its(:'agent.sleep_time') { should == 60.0 }

        it "does not log the event" do
          Appsignal.logger.should_not_receive(:error)
        end
      end

      context "with 420" do
        let(:code) { '420' }

        its(:'agent.sleep_time') { should == 90.0 }
      end

      context "with 413" do
        let(:code) { '413' }

        its(:'agent.sleep_time') { should == 60.0 }
      end
    end

    context "bad responses" do
      context "with 429" do
        let(:code) { '429' }

        it "calls a stop to logging" do
          subject.agent.should_receive(:shutdown).with(false, 429)
        end
      end

      context "with 406" do
        let(:code) { '406' }

        it "calls a stop to logging" do
          subject.agent.should_receive(:shutdown).with(false, 406)
        end
      end

      context "with 402" do
        let(:code) { '402' }

        it "calls a stop to logging" do
          subject.agent.should_receive(:shutdown).with(false, 402)
        end
      end

      context "with 401" do
        let(:code) { '401' }

        it "calls a stop to logging" do
          subject.agent.should_receive(:shutdown).with(false, 401)
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
end
