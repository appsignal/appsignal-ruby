require 'spec_helper'

describe Appsignal::TransactionFormatter::FaultyRequestFormatter do
  let(:parent) { Appsignal::TransactionFormatter }
  let(:transaction) { transaction_with_exception }
  let(:faulty) { parent::FaultyRequestFormatter.new(transaction) }
  subject { faulty }

  describe "#to_hash" do
    it "can call #to_hash on its superclass" do
      parent.new(transaction).respond_to?(:to_hash).should be_true
    end

    context "return value" do
      subject { faulty.to_hash }
      before { faulty.stub(:formatted_exception => :faulty_request) }

      it "includes the exception" do
        subject[:exception].should == :faulty_request
      end
    end
  end

  # protected

  it { should delegate(:backtrace).to(:exception) }
  it { should delegate(:name).to(:exception) }
  it { should delegate(:message).to(:exception) }

  describe "#formatted_exception" do
    subject { faulty.send(:formatted_exception) }

    its(:keys) { should include :backtrace }
    its(:keys) { should include :exception }
    its(:keys) { should include :message }
  end

  describe "#action" do
    it "can call #action on its superclass" do
      parent.new(transaction).respond_to?(:action).should be_true
    end

    context "return value" do
      subject { faulty.send(:action) }

      context "after reaching a controller action" do
        before { faulty.stub(:log_entry => create_log_entry) }

        it { should == 'BlogPostsController#show' }
      end

      context "happened before a controller action was reached" do
        before { faulty.stub(:log_entry => nil) }

        it { should == 'ArgumentError: oh no' }
      end
    end
  end
end
