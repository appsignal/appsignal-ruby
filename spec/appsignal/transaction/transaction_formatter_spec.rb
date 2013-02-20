require 'spec_helper'

describe Appsignal::TransactionFormatter do
  let(:klass) { Appsignal::TransactionFormatter }
  let(:formatter) { klass.new(transaction) }
  let(:transaction) do
    Appsignal::Transaction.create('1', {
      'HTTP_USER_AGENT' => 'IE6',
      'SERVER_NAME' => 'localhost',
      'action_dispatch.routes' => 'not_available'
    })
  end
  subject { formatter }

  describe ".regular" do
    subject { klass.regular(transaction) }
    it { should be_a klass::RegularRequestFormatter }
  end

  describe ".slow" do
    subject { klass.slow(transaction) }
    it { klass.slow(transaction).should be_a klass::SlowRequestFormatter }
  end

  describe ".faulty" do
    subject { klass.faulty(transaction) }
    it { should be_a klass::FaultyRequestFormatter }
  end

  context "a new formatter" do
    describe "#to_hash" do
      subject { formatter.to_hash }
      before { formatter.stub(:action => :foo, :formatted_process_action_event => :bar) }

      it 'returns a formatted hash of the transaction data' do
        should == {
          :request_id => '1',
          :action => :foo,
          :log_entry => :bar,
          :failed => false
        }
      end
    end
  end

  # protected

  it { should delegate(:id).to(:transaction) }
  it { should delegate(:events).to(:transaction) }
  it { should delegate(:exception).to(:transaction) }
  it { should delegate(:exception?).to(:transaction) }
  it { should delegate(:env).to(:transaction) }
  it { should delegate(:request).to(:transaction) }
  it { should delegate(:process_action_event).to(:transaction) }
  it { should delegate(:action).to(:transaction) }

  it { should delegate(:payload).to(:process_action_event) }

  context "a new formatter" do
    describe "#formatted_process_action_event" do
      subject { formatter.send(:formatted_process_action_event) }

      it "calls basic_process_action_event" do
        formatter.should_receive(:basic_process_action_event)
        subject
      end

      context "with actual process action event data" do
        before { transaction.set_process_action_event(create_process_action_event) }

        it { should be_a Hash }

        it "merges formatted_payload on the basic_process_action_event" do
          subject[:duration].should == 1000.0
          subject[:action].should == 'BlogPostsController#show'
        end
      end

      context "without any process action event data" do
        it { should be_a Hash }

        it "does not merge formatted_payload onto the basic_process_action_event" do
          subject.keys.should_not include :duration
          subject.keys.should_not include :action
        end
      end
    end

    describe "#basic_process_action_event" do
      subject { formatter.send(:basic_process_action_event) }
      before do
        transaction.stub(:request => mock(
          :fullpath => '/blog',
          :session => {:current_user => 1})
        )
      end

      it { should == {
        :path => '/blog',
        :kind => 'http_request'
      } }

      it "has no environment key" do
        subject[:environment].should be_nil
      end

      it "has no session_data key" do
        subject[:session_data].should be_nil
      end
    end

    describe "#formatted_payload" do
      let(:start_time) { Time.at(2.71828182) }
      let(:end_time) { Time.at(3.141592654) }
      subject { formatter.send(:formatted_payload) }
      before do
        transaction.stub(:sanitized_event_payload => {})
        transaction.set_process_action_event(mock(
          :name => 'name',
          :duration => 2,
          :time => start_time,
          :end => end_time,
          :payload => {
            :controller => 'controller',
            :action => 'action'
          }
        ))
      end

      it { should == {
        :action => 'controller#action',
        :controller => 'controller', # DEBUG this should no longer be here now
        :duration => 2,
        :time => start_time.to_f,
        :end => end_time.to_f
      } }
    end

    describe "#sanitized_event_payload" do
      subject do
        formatter.send(:sanitized_event_payload, double(:payload => {:key => :sensitive}))
      end

      it "calls Appsignal event payload sanitizer" do
        Appsignal.should_receive(:event_payload_sanitizer).and_return(
          proc do |event|
            event.payload[:key] = 'censored'
            event.payload
          end
        )
        subject.should == {:key => 'censored'}
      end

      it "calls params sanitizer" do
        Appsignal::ParamsSanitizer.should_receive(:sanitize).and_return(
          :key => 'sensitive'
        )
        subject.should == {:key => 'sensitive'}
      end
    end

    describe "#filtered_environment" do
      subject { formatter.send(:filtered_environment) }

      it "should have a SERVER_NAME" do
        subject['SERVER_NAME'].should == 'localhost'
      end

      it "should have a HTTP_USER_AGENT" do
        subject['HTTP_USER_AGENT'].should == 'IE6'
      end

      it "should not have a action_dispatch.routes" do
        subject.should_not have_key 'action_dispatch.routes'
      end
    end
  end
end
