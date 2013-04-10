require 'spec_helper'

describe Appsignal do
  it { should respond_to :subscriber }

  describe ".enqueue" do
    let(:transaction) { regular_transaction }
    subject { Appsignal.enqueue(transaction) }

    it "forwards the call to the agent" do
      Appsignal.agent.should respond_to(:enqueue)
      Appsignal.agent.should_receive(:enqueue).with(transaction)
      subject
    end
  end

  describe ".transactions" do
    subject { Appsignal.transactions }

    it { should be_a Hash }
  end

  describe '.agent' do
    subject { Appsignal.agent }

    it { should be_a Appsignal::Agent }
  end

  describe '.logger' do
    subject { Appsignal.logger }

    it { should be_a Logger }
    its(:level) { should == Logger::INFO }
  end

  describe '.config' do
    subject { Appsignal.config }

    it 'should return the endpoint' do
      subject[:endpoint].should eq 'http://localhost:3000/1'
    end

    it 'should return the api key' do
      subject[:api_key].should eq 'abc'
    end

    it 'should return ignored exceptions' do
      subject[:ignore_exceptions].should eq []
    end

    it 'should return the slow request threshold' do
      subject[:slow_request_threshold].should eq 200
    end
  end

  describe ".post_processing_middleware" do
    before { Appsignal.instance_variable_set(:@post_processing_chain, nil) }

    it "returns the default middleware stack" do
      Appsignal::PostProcessor.should_receive(:default_middleware)
      Appsignal.post_processing_middleware
    end

    it "returns a chain when called without a block" do
      instance = Appsignal.post_processing_middleware
      instance.should be_an_instance_of Appsignal::Middleware::Chain
    end

    context "when passing a block" do
      it "yields an appsignal middleware chain" do
        Appsignal.post_processing_middleware do |o|
          o.should be_an_instance_of Appsignal::Middleware::Chain
        end
      end
    end
  end

  describe '.active?' do
    subject { Appsignal.active? }

    context "without config" do
      before { Appsignal.stub(:config => nil) }

      it { should be_false }
    end

    context "with config but inactive" do
      before { Appsignal.stub(:config => {:active => false}) }

      it { should be_false }
    end

    context "with active config" do
      before { Appsignal.stub(:config => {:active => true}) }

      it { should be_true }
    end
  end
end
