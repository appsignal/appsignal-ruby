require 'spec_helper'

describe Appsignal::PostProcessor do
  let(:klass) { Appsignal::PostProcessor }
  let(:post_processor) { klass.new(transactions) }
  let(:transaction) { regular_transaction }
  let(:transactions) { [transaction] }

  describe "#initialize" do
    subject { klass.new(:foo) }

    its(:transactions) { should == :foo }
  end

  describe "#post_processed_queue!" do
    it "calls the post procesing middleware chain" do
      transaction.stub(:events => [:foo, :foo])
      Appsignal.post_processing_middleware.
        should_receive(:invoke).with(:foo).twice
    end

    it "calls to hash on the transaction" do
      transaction.should respond_to(:to_hash)
      transaction.should_receive(:to_hash)
    end

    after { post_processor.post_processed_queue! }
  end

  describe ".default_middleware" do
    subject { klass.default_middleware }

    it { should be_instance_of Appsignal::Middleware::Chain }
  end
end
