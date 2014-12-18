require 'spec_helper'

class Smash < Hash
  def []=(key, val)
    raise 'the roof'
  end
end

describe Appsignal::Transaction do
  before :all do
    start_agent
  end

  let(:time) { Time.at(fixed_time) }

  before { Timecop.freeze(time) }
  after  { Timecop.return }

  context "class methods" do
    describe '.create' do
      subject { Appsignal::Transaction.create('1', {}) }

      it 'should add the transaction to thread local' do
        subject
        Thread.current[:appsignal_transaction].should == subject
      end

      it "should create a transaction" do
        subject.should be_a Appsignal::Transaction
        subject.request_id.should == '1'
      end
    end

    describe '.current' do
      let(:transaction) { Appsignal::Transaction.create('1', {}) }
      before { transaction }
      subject { Appsignal::Transaction.current }

      it 'should return the correct transaction' do
        should eq transaction
      end
    end

    describe "complete_current!" do
      before { Thread.current[:appsignal_transaction] = nil }

      context "with a current transaction" do
        before { Appsignal::Transaction.create('2', {}) }

        it "should complete the current transaction and set the thread appsignal_transaction to nil" do
          Appsignal::Transaction.current.should_receive(:complete!)

          Appsignal::Transaction.complete_current!

          Thread.current[:appsignal_transaction].should be_nil
        end
      end

      context "without a current transaction" do
        it "should not raise an error" do
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end

  context "with transaction instance" do
    let(:env) do
      {
        'HTTP_USER_AGENT' => 'IE6',
        'SERVER_NAME' => 'localhost',
        'action_dispatch.routes' => 'not_available',
        'HTTP_X_REQUEST_START' => '1000000'
      }
    end
    let(:transaction) { Appsignal::Transaction.create('3', env) }

    context "initialization" do
      subject { transaction }

      its(:request_id)         { should == '3' }
      its(:events)             { should == [] }
      its(:root_event_payload) { should be_nil }
      its(:exception)          { should be_nil }
      its(:env)                { should == env }
      its(:tags)               { should == {} }
      its(:time)               { should == fixed_time }
      its(:duration)           { should be_nil }
      its(:timestack)          { should == [] }
    end

    describe '#request' do
      subject { transaction.request }

      it { should be_a ::Rack::Request }
    end

    describe "#set_tags" do
      it "should add tags to transaction" do
        expect {
          transaction.set_tags({'a' => 'b'})
        }.to change(transaction, :tags).to({'a' => 'b'})
      end
    end

    describe '#set_root_event' do
      before { transaction.set_root_event(name, payload) }

      context "for a process_action event" do
        let(:name)    { 'process_action.action_controller' }
        let(:payload) { create_payload }

        it "should set the root event payload" do
          transaction.root_event_payload.should == payload
        end

        it "should set the action" do
          transaction.action.should == 'BlogPostsController#show'
        end

        it "should set the kind" do
          transaction.kind.should == 'http_request'
        end

        it "should call set_http_queue_start" do
          transaction.queue_start.should_not be_nil
        end
      end

      context "for a perform_job event" do
        let(:name)    { 'perform_job.delayed_job' }
        let(:payload) { create_background_payload }

        it "should set the root event payload" do
          transaction.root_event_payload.should == payload
        end

        it "should set the action" do
          transaction.action.should == 'BackgroundJob#perform'
        end

        it "should set the kind" do
          transaction.kind.should == 'background_job'
        end

        it "should set call set_background_queue_start" do
          transaction.queue_start.should_not be_nil
        end
      end
    end

    describe '#add_event' do
      it 'should add an event' do
        expect {
          transaction.add_event('digest', 'name', 0.0, 0.0, 0.0, 0)
        }.to change(transaction, :events).to([{
          :digest         => 'digest',
          :name           => 'name',
          :started        => 0.0,
          :duration       => 0.0,
          :child_duration => 0.0,
          :level          => 0
        }])
      end
    end

    context "adding exception" do
      let(:exception) { double(:exception, :name => 'test') }

      describe '#add_exception' do
        it 'should add an exception' do
          expect {
            transaction.add_exception(exception)
          }.to change(transaction, :exception).to(exception)
        end
      end

      describe "#exception?" do
        subject { transaction.exception? }

        context "without an exception" do
          it { should be_false }
        end

        context "without an exception" do
          before { transaction.add_exception(exception) }

          it { should be_true }
        end
      end
    end

    describe '#to_hash' do
      before do
        transaction.set_root_event('process_action.action_controller', create_payload)
      end

      subject { transaction.to_hash }

      context "regular" do
        before do
          transaction.instance_variable_set(:@duration, 0.1)
          transaction.add_event('digest', 'name', 0.0, 0.0, 0.0, 0)
          transaction.instance_variable_set(:@queue_start, nil)
        end

        its([:action])         { should == 'BlogPostsController#show' }
        its([:time])           { should == time.to_f }
        its([:kind])           { should == 'http_request' }
        its([:duration])       { should == 0.1 }
        its([:queue_duration]) { should be_nil }
        its([:events])         { should == [{
          :digest         => 'digest',
          :name           => 'name',
          :started        => 0.0,
          :duration       => 0.0,
          :child_duration => 0.0,
          :level          => 0
        }] }

        context "with queue time set" do
          before { transaction.instance_variable_set(:@queue_start, fixed_time - 0.1) }

          its([:queue_duration]) { should be_within(0.01).of(0.1) }
        end
      end

      context "with exception" do
        before do
          error = StandardError.new('test error')
          error.set_backtrace(['line 1'])
          transaction.add_exception(error)
          transaction.set_tags(:user_id => 1)
        end

        its([:action])       { should == 'BlogPostsController#show' }
        its([:time])         { should == time.to_f }
        its([:kind])         { should == 'http_request' }
        its([:overview])     { should == {
          :path           => '/blog',
          :request_format => 'html',
          :request_method => 'GET'
        } }
        its([:params])       { should == {
          'controller' => 'blog_posts',
          'action'     => 'show',
          'id'         => '1'
        } }
        its([:environment])  { should be_a(Hash) }
        its([:environment])  { should include('SERVER_NAME') }
        its([:session_data]) { should == {} }
        its([:tags])         { should == {:user_id => 1} }
        its([:exception])    { should == {
          :exception => 'StandardError',
          :message   => 'test error',
          :backtrace => ['line 1']
        } }
      end
    end

    describe '#complete!' do
      before do
        Appsignal::IPC.stub(:current => nil)
        transaction.set_root_event('process_action.action_controller', {})
      end

      it 'should remove transaction from the thread local variable' do
        Appsignal::Transaction.current.should be_present
        transaction.complete!
        Appsignal::Transaction.current.should be_nil
      end

      it "should set the duration" do
        advance_frozen_time(time, 0.5)
        transaction.complete!

        transaction.duration.should == 0.5
      end

      context 'adding transaction' do
        context 'sanity check' do
          specify { Appsignal.should respond_to(:add_transaction) }
        end

        context 'without events and without exception' do
          it 'should add transaction to the agent' do
            Appsignal.should_receive(:add_transaction).with(instance_of(Hash))
          end
        end

        context 'with events' do
          before { transaction.add_event('digest', 'name', 0.0, 0.0, 0.0, 0) }

          it 'should add transaction to the agent' do
            Appsignal.should_receive(:add_transaction).with(instance_of(Hash))
          end
        end

        context 'with exception' do
          before { transaction.add_exception(StandardError.new) }

          it 'should add transaction to the agent' do
            Appsignal.should_receive(:add_transaction).with(instance_of(Hash))
          end
        end

        after { transaction.complete! }
      end

      context 'when using IPC' do
        before do
          Appsignal::IPC::Client.start
        end
        after do
          Appsignal::IPC::Client.stop
        end

        it "should send itself through the rabbit hole" do
          Appsignal::IPC::Client.should_receive(:add_transaction).with(instance_of(Hash))
        end

        after { transaction.complete! }
      end
    end

    # protected

    describe "#set_background_queue_start" do
      before do
        transaction.stub(:root_event_payload => payload)
        transaction.send(:set_background_queue_start)
      end

      subject { transaction.queue_start }

      context "when queue start is nil" do
        let(:payload) { create_background_payload(:queue_start => nil) }

        it { should be_nil }
      end

      context "when queue start is set" do
        let(:payload) { create_background_payload }

        it { should == 1389783590.0 }
      end
    end

    describe "#set_http_queue_start" do
      let(:slightly_earlier_time) { fixed_time - 0.4 }
      let(:slightly_earlier_time_in_ms) { (slightly_earlier_time.to_f * 1000).to_i }
      before { transaction.send(:set_http_queue_start) }
      subject { transaction.queue_start }

      context "without env" do
        let(:env) { nil }

        it { should be_nil }
      end

      context "with no relevant header set" do
        let(:env) { {} }

        it { should be_nil }
      end

      context "with the HTTP_X_REQUEST_START header set" do
        let(:env) { {'HTTP_X_REQUEST_START' => "t=#{slightly_earlier_time_in_ms}"} }

        it { should == 1389783599.6 }

        context "with unparsable content" do
          let(:env) { {'HTTP_X_REQUEST_START' => 'something'} }

          it { should be_nil }
        end

        context "with some cruft" do
          let(:env) { {'HTTP_X_REQUEST_START' => "t=#{slightly_earlier_time_in_ms}aaaa"} }

          it { should == 1389783599.6 }
        end

        context "with the alternate HTTP_X_QUEUE_START header set" do
          let(:env) { {'HTTP_X_QUEUE_START' => "t=#{slightly_earlier_time_in_ms}"} }

          it { should == 1389783599.6 }
        end
      end
    end

    describe "#queue_duration" do
      subject { transaction.send(:queue_duration) }

      context "with no queue start set" do
        let(:transaction) { regular_transaction }

        it { should be_nil }
      end

      context "with queue start set" do
        let(:transaction) { regular_transaction_with_x_request_start }

        it { should be_within(0.001).of(0.04) }

        pending "double check this calculation"
      end
    end

    describe "#sanitized_params" do
      subject { transaction.send(:sanitized_params) }

      context "without a root event payload" do
        it { should be_nil }
      end

      context "with a root event payload" do
        before { transaction.stub(:root_event_payload => create_payload) }

        it "should call the params sanitizer" do
          Appsignal::ParamsSanitizer.should_receive(:sanitize).with(kind_of(Hash)).and_return({:id => 1})

          subject.should == {:id => 1}
        end
      end
    end

    describe "#sanitized_environment" do
      let(:whitelisted_keys) { Appsignal::Transaction::ENV_METHODS }
      let(:transaction) { Appsignal::Transaction.create('1', env) }

      subject { transaction.send(:sanitized_environment) }

      context "when env is nil" do
        let(:env) { nil }

        it { should be_nil }
      end

      context "when env is present" do
        let(:env) do
          Hash.new.tap do |hash|
            whitelisted_keys.each { |o| hash[o] = 1 } # use all whitelisted keys
            hash[whitelisted_keys] = nil # don't add if nil
            hash[:not_whitelisted] = 'I will be sanitized'
          end
        end

        its(:keys) { should =~ whitelisted_keys[0, whitelisted_keys.length] }
      end
    end

    describe '#sanitized_session_data' do
      subject { transaction.send(:sanitized_session_data) }

      before do
        transaction.should respond_to(:request)
        transaction.stub_chain(:request, :session => {:foo => :bar})
        transaction.stub_chain(:request, :fullpath => :bar)
      end

      it "passes the session data into the params sanitizer" do
        Appsignal::ParamsSanitizer.should_receive(:sanitize).with({:foo => :bar}).
          and_return(:sanitized_foo)
        subject.should == :sanitized_foo
      end

      if defined? ActionDispatch::Request::Session
        context "with ActionDispatch::Request::Session" do
          before do
            transaction.should respond_to(:request)
            transaction.stub_chain(:request, :session => action_dispatch_session)
            transaction.stub_chain(:request, :fullpath => :bar)
          end

          it "should return an session hash" do
            Appsignal::ParamsSanitizer.should_receive(:sanitize).with({'foo' => :bar}).
              and_return(:sanitized_foo)
            subject
          end

          def action_dispatch_session
            store = Class.new {
              def load_session(env); [1, {:foo => :bar}]; end
              def session_exists?(env); true; end
            }.new
            ActionDispatch::Request::Session.create(store, {}, {})
          end
        end
      end

      context "when skipping session data" do
        before do
          Appsignal.config = {:skip_session_data => true}
        end

        it "does not pass the session data into the params sanitizer" do
          Appsignal::ParamsSanitizer.should_not_receive(:sanitize)
          subject.should be_nil
        end
      end
    end

    describe '#sanitized_tags' do
      let(:transaction) { Appsignal::Transaction.create('1', {}) }
      before do
        transaction.set_tags(
          {
            :valid_key => 'valid_value',
            'valid_string_key' => 'valid_value',
            :both_symbols => :valid_value,
            :integer_value => 1,
            :hash_value => {'invalid' => 'hash'},
            :array_value => ['invalid', 'array'],
            :to_long_value => SecureRandom.urlsafe_base64(101),
            :object => Object.new,
            SecureRandom.urlsafe_base64(101) => 'to_long_key'
          }
        )
      end
      subject { transaction.send(:sanitized_tags).keys }

      it "should only return whitelisted data" do
        should =~ [
          :valid_key,
          'valid_string_key',
          :both_symbols,
          :integer_value
        ]
      end
    end

    describe "#cleaned_backtrace" do
      let(:transaction) { regular_transaction }

      subject { transaction.send(:cleaned_backtrace) }

      context "without an exception" do
        it { should be_nil }
      end

      context "with an exception" do
        before do
          error = StandardError.new('test error')
          error.set_backtrace(['line 1'])
          transaction.add_exception(error)
        end

        it { should be_a(Array) }
      end

      pending "calls Rails backtrace cleaner if Rails is present"
    end
  end
end
