require 'spec_helper'

describe Appsignal::Agent::Aggregator do
  let(:aggregator) { Appsignal::Agent::Aggregator.new }
  let(:transaction) { double }

  context "initialization" do
    its(:transactions) { should == [] }
    its(:event_details) { should == [] }
  end

  describe "#add_transaction" do
    it "should add the transaction" do
      aggregator.add_transaction(transaction)

      aggregator.transactions.should have(1).item
      aggregator.transactions.first.should == transaction
    end
  end

  describe "#add_event_details" do
    it "should add event details" do
      aggregator.add_event_details('digest', 'name', 'title', 'body')

      aggregator.event_details.should have(1).item
      aggregator.event_details.first.should == {
        :digest  => 'digest',
        :name    => 'name',
        :title   => 'title',
        :body    => 'body'
      }
    end
  end

  describe "#any?" do
    subject { aggregator.any? }

    it { should be_false }

    context "with transactions" do
      before { aggregator.add_transaction('') }

      it { should be_true }
    end

    context "with event details" do
      before { aggregator.add_event_details('digest', 'name', 'title', 'body') }

      it { should be_true }
    end
  end

  describe "#to_json" do
    subject { JSON.parse(aggregator.to_json) }

    it { should == {'transactions' => [], 'event_details' => []} }

    context "with transactions" do
      before { aggregator.add_transaction({:action => 'something'}) }

      it { should == {
        'transactions'  => [{'action' => 'something'}],
        'event_details' => []
      } }
    end

    context "with event details" do
      before { aggregator.add_event_details('digest', 'name', 'title', 'body') }

      it { should == {
        'transactions'  => [],
        'event_details' => [{"digest" => "digest", "name" => "name", "title" => "title", "body" => "body"}]
      } }
    end
  end
end
