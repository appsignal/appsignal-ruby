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
    let(:start_time) { Time.at(2.71828182) }
    let(:end_time) { Time.at(3.141592654) }
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
        :time => start_time.to_f,
        :end => end_time.to_f,
        :payload => :sanitized
      } }
    end
  end

  describe "#basic_log_entry" do
    subject { slow.send(:basic_log_entry) }

    it "should return a hash with extra keys" do
      subject[:environment].should == {
        "HTTP_USER_AGENT" => "IE6",
        "SERVER_NAME" => "localhost"
      }
      subject[:session_data].should == {}
    end
  end
end
