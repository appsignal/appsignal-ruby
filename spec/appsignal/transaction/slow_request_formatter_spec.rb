require 'spec_helper'


describe Appsignal::TransactionFormatter::SlowRequestFormatter do
  let(:parent) { Appsignal::TransactionFormatter }
  let(:transaction) { slow_transaction }
  let(:klass) { parent::SlowRequestFormatter }
  let(:slow) { klass.new(transaction) }

  describe "#to_hash" do
    subject { slow.to_hash }
    before { slow.stub(:detailed_events => :startled) }

    it "includes events" do
      subject[:events].should == :startled
    end
  end

  # protected

  context "with an event" do
    let(:start_time) { Time.parse('01-01-2001 10:00:00') }
    let(:end_time) { Time.parse('01-01-2001 10:00:01') }
    let(:event) do
      mock(
        :event,
        :name => 'Startled',
        :duration => 2,
        :time => start_time,
        :end => end_time,
        :payload => {
          :controller => 'controller',
          :action => 'action',
          :sensitive => 'data'
        }
      )
    end

    describe "#detailed_events" do
      subject { slow.send(:detailed_events) }
      before do
        slow.stub(
          :events => [event],
          :format => :foo
        )
      end

      it { should == [:foo] }
    end

    describe "#format" do
      subject { slow.send(:format, event) }
      before { slow.stub(:sanitized_event_payload => :sanitized) }

      it { should == {
        :name => 'Startled',
        :duration => 2,
        :time => start_time,
        :end => end_time,
        :payload => :sanitized
      } }
    end
  end
end
