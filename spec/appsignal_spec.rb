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

  describe ".tag_request" do
    before { Appsignal::Transaction.stub(:current => transaction) }

    context "with transaction" do
      let(:transaction) { double }

      it "should call set_tags on transaction" do
        transaction.should_receive(:set_tags).with({'a' => 'b'})
      end

      after { Appsignal.tag_request({'a' => 'b'}) }
    end

    context "without transaction" do
      let(:transaction) { nil }

      it "should call set_tags on transaction" do
        Appsignal.tag_request.should be_false
      end
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
      subject[:api_key].should eq 'ghi'
    end

    it 'should return ignored exceptions' do
      subject[:ignore_exceptions].should eq []
    end

    it 'should return the slow request threshold' do
      subject[:slow_request_threshold].should eq 200
    end
  end

  describe ".json" do
    subject { Appsignal.json }

    it { should == ActiveSupport::JSON }
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

  describe ".send_exception" do
    it "should send the exception to AppSignal" do
      agent = double
      Appsignal.stub(:agent).and_return(agent)
      agent.should_receive(:send_queue)
      agent.should_receive(:enqueue).with(kind_of(Appsignal::Transaction))

      Appsignal::Transaction.should_receive(:create).and_call_original
    end

    it "should not send the exception if it's in the ignored list" do
      Appsignal.stub(:is_ignored_exception? => true)
      Appsignal::Transaction.should_not_receive(:create)
    end

    after do
      begin
        raise "I am an exception"
      rescue Exception => e
        Appsignal.send_exception(e)
      end
    end
  end

  describe ".listen_for_exception" do
    it "should call send_exception and re-raise" do
      Appsignal.should_receive(:send_exception).with(kind_of(Exception))
      lambda {
        Appsignal.listen_for_exception do
          raise "I am an exception"
        end
      }.should raise_error(RuntimeError, "I am an exception")
    end
  end
end
