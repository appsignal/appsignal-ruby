require 'spec_helper'

describe Appsignal::Aggregator::PostProcessor do
  before :all do
    start_agent
  end

  let(:klass) { Appsignal::Aggregator::PostProcessor }
  let(:post_processor) { klass.new(transactions) }

  describe "#initialize" do
    subject { klass.new(:foo) }

    its(:transactions) { should == :foo }
  end

  describe "#post_processed_queue!" do
    let(:first_transaction) { regular_transaction }
    let(:second_transaction) do
      slow_transaction(
        :events => [
          notification_event(
            :payload => {
              :set_value => 'set value',
              :nil_value => nil
            }
          )
        ]
      )
    end
    let(:transactions) { [first_transaction, second_transaction] }
    let(:processed_queue) { post_processor.post_processed_queue! }
    subject { processed_queue }

    it { should have(2).items }

    context "the first transaction" do
      subject { processed_queue[0] }

      it { should_not have_key(:events) }

      context "log entry" do
        subject { processed_queue[0][:log_entry] }

        it { should have_key(:duration) }
        it { should have_key(:end) }
        it { should_not have_key(:events) }
      end
    end

    context "the second transaction" do
      context "log entry" do
        subject { processed_queue[1][:log_entry] }

        it { should have_key(:duration) }
        it { should have_key(:end) }
      end

      context "first event" do
        subject { processed_queue[1][:events][0] }

        it { should_not be_nil }
        it { should have_key(:name) }

        it "should have the set value in the payload" do
          subject[:payload][:set_value].should == 'set value'
        end

        it "should not have the nil value in the payload"\
           "since delete blanks is in the middle ware stack" do
          subject[:payload].should_not have_key(:nil_value)
        end
      end
    end
  end

  describe ".default_middleware" do
    subject { klass.default_middleware }

    it { should be_instance_of Appsignal::Middleware::Chain }

    it "should include the default middleware stack" do
      subject.exists?(Appsignal::Middleware::DeleteBlanks).should be_true
      if rails_present?
        subject.exists?(Appsignal::Middleware::ActionViewSanitizer).should be_true
        subject.exists?(Appsignal::Middleware::ActiveRecordSanitizer).should be_true
      else
        subject.exists?(Appsignal::Middleware::ActionViewSanitizer).should be_false
        subject.exists?(Appsignal::Middleware::ActiveRecordSanitizer).should be_false
      end
    end
  end
end
