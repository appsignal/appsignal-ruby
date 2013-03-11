require 'spec_helper'

describe Appsignal::Aggregator do
  let(:aggregator) { Appsignal::Aggregator.new }

  describe "#add" do
    subject { aggregator.add(transaction) }

    context "adding a regular transaction" do
      let(:transaction) { regular_transaction }

      specify { transaction.should_receive(:truncate!) }
    end

    context "adding a slow transaction" do
      let(:transaction) { slow_transaction }

      specify {
        aggregator.should_receive(:pre_process_slowness!).with(transaction)
      }
    end

    context "adding a transaction with an exception" do
      let(:transaction) { transaction_with_exception }

      specify { transaction.should_receive(:convert_values_to_primitives!) }
    end

    after { subject }
  end

  describe "#post_process!" do
    let(:transaction) { slow_transaction }
    let(:other_transaction) { regular_transaction }
    subject { aggregator.post_process! }
    before do
      aggregator.add(transaction)
      aggregator.add(other_transaction)
    end

    it { should be_a Array }

    it "calls to_hash on each transaction in the queue" do
      transaction.should_receive(:to_hash)
      other_transaction.should_receive(:to_hash)
      subject
    end
  end

  # protected

  describe "#similar_slowest" do
    subject { aggregator.send(:similar_slowest, transaction) }
    before { aggregator.add(other_transaction) }

    context "passing a transaction concerning a different action" do
      let(:transaction) { slow_transaction }
      let(:other_transaction) do
        time = Time.parse('01-01-2001 10:01:00')
        appsignal_transaction(
          :process_action_event => notification_event(
            :payload => create_payload(
              :action => 'show',
              :controller => 'SomeOtherController'
            )
          )
        )
      end

      it { should be_nil }
    end

    context "passing concerning the same action" do
      let(:transaction) { slow_transaction }
      let(:other_transaction) { slower_transaction }

      it { should == other_transaction }
    end
  end

  describe "#pre_process_slowness!" do
    subject { aggregator.send(:pre_process_slowness!, transaction) }

    context "without a similar slow transaction" do
      let(:transaction) { slow_transaction }

      it "calls convert_values_to_primitives on transaction" do
        transaction.should_receive(:convert_values_to_primitives!)
        subject
      end

      it "indexes the slow transaction" do
        expect { subject }.to change(aggregator, :slowness_index).
          to({transaction.action => transaction})
      end
    end

    context "with a non similar slow transaction" do
      let(:transaction) { slow_transaction }
      let(:other_transaction) do
        time = Time.parse('01-01-2001 10:01:00')
        appsignal_transaction(
          :process_action_event => notification_event(
            :action => 'foooo',
            :start => time,
            :ending => time + Appsignal.config[:slow_request_threshold] / 500.0
          )
        )
      end

      it "calls convert_values_to_primitives on transaction" do
        transaction.should_receive(:convert_values_to_primitives!)
        subject
      end

      it "indexes the slow transaction" do
        expect { subject }.to change(aggregator, :slowness_index).to({
          other_transaction.action => other_transaction,
          transaction.action => transaction
        })
      end
    end

    context "with a similar but slower transaction" do
      let(:transaction) { slow_transaction }
      let(:slower) { slower_transaction }
      before { aggregator.add(slower) }

      it "calls truncate on the transaction" do
        transaction.should_receive(:truncate!)
        transaction.should_not_receive(:convert_values_to_primitives!)
        subject
      end

      it "does not index the slow transaction" do
        expect { subject }.to_not change(aggregator, :slowness_index)
      end

      it "does not modify the slow transaction" do
        slower.should_not_receive(:truncate!)
        slower.should_not_receive(:convert_values_to_primitives!)
        subject
      end
    end

    context "with a similar but faster transaction" do
      let(:transaction) { slower_transaction }
      let(:faster_transaction) { slow_transaction }
      before { aggregator.add(faster_transaction) }

      it "calls truncate on the faster transaction" do
        faster_transaction.should_receive(:truncate!)
        subject
      end

      it "calls convert_values_to_primitives on the (slower) transaction" do
        transaction.should_receive(:convert_values_to_primitives!)
        subject
      end

      it "indexes the slow transaction" do
        expect { subject }.to change(aggregator, :slowness_index).
          to({faster_transaction.action => transaction})
      end
    end
  end

end
