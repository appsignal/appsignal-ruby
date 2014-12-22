require 'spec_helper'

describe Appsignal::Agent::Aggregator do
  let(:aggregator) { Appsignal::Agent::Aggregator.new }
  let(:transaction) { double }

  context "initialization" do
    its(:transactions)  { should == [] }
    its(:event_details) { should == [] }
    its(:measurements)  { should == {} }
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

  describe "#add_measurement" do
    it "should return nil" do
      aggregator.add_measurement('digest', 'name', 0, {}).should be_nil
    end

    it "should add a new measurement" do
      timestamp = 1210
      aggregator.add_measurement('digest', 'name', timestamp, :c => 1, :d => 20.0)

      aggregator.measurements[1200].should have(1).item
      aggregator.measurements[1200]['digest_name'].should == {
        :digest => 'digest',
        :name   => 'name',
        :c      => 1,
        :d      => 20.0
      }
    end

    it "should add a measurement that already has data" do
      timestamp = 1210
      aggregator.add_measurement('digest', 'name', timestamp, :c => 1, :d => 20.0)
      aggregator.add_measurement('digest', 'name', timestamp, :c => 1, :d => 50.0)

      aggregator.measurements[1200].should have(1).item
      aggregator.measurements[1200]['digest_name'].should == {
        :digest => 'digest',
        :name   => 'name',
        :c      => 2,
        :d      => 70.0
      }
    end

    it "should add a second new measurement" do
      timestamp = 1210
      aggregator.add_measurement('digest', 'name', timestamp, :c => 1, :d => 20.0)
      aggregator.add_measurement('digest2', 'name2', timestamp, :c => 2, :d => 40.0)

      aggregator.measurements[1200].should have(2).items
      aggregator.measurements[1200]['digest_name'].should == {
        :digest => 'digest',
        :name   => 'name',
        :c      => 1,
        :d      => 20.0
      }
      aggregator.measurements[1200]['digest2_name2'].should == {
        :digest => 'digest2',
        :name   => 'name2',
        :c      => 2,
        :d      => 40.0
      }
    end
  end

  describe "#rounded_timestamp" do
    subject { aggregator.rounded_timestamp(fixed_time.to_i) }

    it { should == 1389783600 }

    context "53 seconds later" do
      subject { aggregator.rounded_timestamp(fixed_time.to_i + 53) }

      it { should == 1389783600 }
    end

    context "105 seconds later" do
      subject { aggregator.rounded_timestamp(fixed_time.to_i + 105) }

      it { should == 1389783660 }
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

    context "with measurements" do
      before { aggregator.add_measurement('digest', 'name', 11111, {}) }

      it { should be_true }
    end
  end

  describe "#to_json" do
    subject { JSON.parse(aggregator.to_json) }

    it { should == {'transactions' => [], 'event_details' => [], 'measurements' => {}} }

    context "with transactions" do
      before { aggregator.add_transaction({:action => 'something'}) }

      it { should == {
        'transactions'  => [{'action' => 'something'}],
        'event_details' => [],
        'measurements' => {}
      } }
    end

    context "with event details" do
      before { aggregator.add_event_details('digest', 'name', 'title', 'body') }

      it { should == {
        'transactions'  => [],
        'event_details' => [{"digest" => "digest", "name" => "name", "title" => "title", "body" => "body"}],
        'measurements' => {}
      } }
    end

    context "with measurements" do
      before { aggregator.add_measurement('digest', 'name', 1200, :c => 1, :d => 20.0) }

      it { should == {
        'transactions'  => [],
        'event_details' => [],
        'measurements' => {"1200" => [{"digest" => "digest", "name" => "name", "c" => 1, "d" => 20.0}]}
      } }
    end
  end
end
