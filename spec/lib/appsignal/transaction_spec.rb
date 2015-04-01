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
        Appsignal::Native.should_receive(:start_transaction).with('1')
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
        should == transaction
      end
    end

    describe "complete_current!" do
      before { Thread.current[:appsignal_transaction] = nil }

      context "with a current transaction" do
        before { Appsignal::Transaction.create('2', {}) }

        it "should complete the current transaction and set the thread appsignal_transaction to nil" do
          Appsignal::Native.should_receive(:finish_transaction).with('2')

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
      its(:root_event_payload) { should be_nil }
      its(:exception)          { should be_nil }
      its(:env)                { should == env }
      its(:tags)               { should == {} }
      its(:queue_start)        { should == -1 }
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
      context "for a process_action event" do
        let(:name)    { 'process_action.action_controller' }
        let(:payload) { create_payload }

        it "should set the meta data in the transaction and native" do
          Appsignal::Native.should_receive(:set_transaction_basedata).with(
            '3',
            'http_request',
            'BlogPostsController#show',
            kind_of(Integer)
          )

          metadata = {
            'path'           => '/blog',
            'request_format' => 'html',
            'request_method' => 'GET',
            'status'         => '200'
          }
          metadata.each do |key, value|
            transaction.should_receive(:set_metadata).with(key, value).once
          end

          transaction.set_root_event(name, payload)

          transaction.root_event_payload.should == payload
          transaction.action.should == 'BlogPostsController#show'
          transaction.kind.should == 'http_request'
          transaction.queue_start.should be_kind_of(Integer)
        end
      end

      context "for a perform_job event" do
        let(:name)    { 'perform_job.delayed_job' }
        let(:payload) { create_background_payload }

        it "should set the meta data in the transaction and native" do
          Appsignal::Native.should_receive(:set_transaction_basedata).with(
            '3',
            'background_job',
            'BackgroundJob#perform',
            kind_of(Integer)
          )

          transaction.set_root_event(name, payload)

          transaction.root_event_payload.should == payload
          transaction.action.should == 'BackgroundJob#perform'
          transaction.kind.should == 'background_job'
          transaction.queue_start.should be_kind_of(Integer)
        end
      end
    end

    describe "#set_metadata" do
      it "should set the metdata in native" do
        Appsignal::Native.should_receive(:set_transaction_metadata).with(
          '3',
          'request_method',
          'GET'
        ).once

        transaction.set_metadata('request_method', 'GET')
      end

      it "should set the metdata in native when value is nil" do
        Appsignal::Native.should_not_receive(:set_transaction_metadata)

        transaction.set_metadata('request_method', nil)
      end
    end

    describe '#set_error' do
      let(:error) { double(:error, :message => 'test message', :backtrace => ['line 1']) }

      it "should also respond to add_exception for backwords compatibility" do
        transaction.should respond_to(:add_exception)
      end

      it "should set an error and it's data in native" do
        Appsignal::Native.should_receive(:set_transaction_error).with(
          '3',
          'RSpec::Mocks::Mock',
          'test message'
        )
        Appsignal::Native.should_receive(:set_transaction_error_data).with(
          '3',
          'environment',
          "{\"SERVER_NAME\":\"localhost\",\"HTTP_X_REQUEST_START\":\"1000000\",\"HTTP_USER_AGENT\":\"IE6\"}"
        ).once
        Appsignal::Native.should_receive(:set_transaction_error_data).with(
          '3',
          'session_data',
          "{}"
        ).once
        Appsignal::Native.should_receive(:set_transaction_error_data).with(
          '3',
          'backtrace',
          "[\"line 1\"]"
        ).once
        Appsignal::Native.should_receive(:set_transaction_error_data).with(
          '3',
          'tags',
          "{}"
        ).once

        transaction.set_error(error)
      end

      context "with root event payload" do
        before do
          transaction.set_root_event('process_action.action_controller', create_payload)
        end

        it "should also set params" do
          Appsignal::Native.should_receive(:set_transaction_error_data).with(
            '3',
            'params',
            '{"controller":"blog_posts","action":"show","id":"1"}'
          ).once
          Appsignal::Native.should_receive(:set_transaction_error_data).with(
            '3',
            kind_of(String),
            kind_of(String)
          ).exactly(4).times

          transaction.set_error(error)
        end
      end

      context "with a non-json convertable type" do
        before do
          transaction.stub(:sanitized_params => 'a string')
        end

        it "should skip the field" do
          Appsignal::Native.should_not_receive(:set_transaction_error_data).with(
            '3',
            'params',
            kind_of(String)
          )
          Appsignal::Native.should_receive(:set_transaction_error_data).with(
            '3',
            kind_of(String),
            kind_of(String)
          ).exactly(4).times

          transaction.set_error(error)
        end
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

        it { should == -1 }
      end

      context "when queue start is set" do
        let(:payload) { create_background_payload }

        it { should == 1389783590000 }
      end
    end

    describe "#set_http_queue_start" do
      let(:slightly_earlier_time) { fixed_time - 0.4 }
      let(:slightly_earlier_time_in_ms) { (slightly_earlier_time.to_f * 1000).to_i }
      before { transaction.send(:set_http_queue_start) }
      subject { transaction.queue_start }

      context "without env" do
        let(:env) { nil }

        it { should == -1 }
      end

      context "with no relevant header set" do
        let(:env) { {} }

        it { should == -1 }
      end

      context "with the HTTP_X_REQUEST_START header set" do
        let(:env) { {'HTTP_X_REQUEST_START' => "t=#{slightly_earlier_time_in_ms}"} }

        it { should == 1389783599600 }

        context "with unparsable content" do
          let(:env) { {'HTTP_X_REQUEST_START' => 'something'} }

          it { should == -1 }
        end

        context "with some cruft" do
          let(:env) { {'HTTP_X_REQUEST_START' => "t=#{slightly_earlier_time_in_ms}aaaa"} }

          it { should == 1389783599600 }
        end

        context "with the alternate HTTP_X_QUEUE_START header set" do
          let(:env) { {'HTTP_X_QUEUE_START' => "t=#{slightly_earlier_time_in_ms}"} }

          it { should == 1389783599600 }
        end
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

      context "when env is nil" do
       let(:transaction) { Appsignal::Transaction.create('1', nil) }

        it { should be_nil }
      end

      context "when env is empty" do
       let(:transaction) { Appsignal::Transaction.create('1', {}) }

        it { should == {} }
      end

      context "when there is a session" do
       let(:transaction) { Appsignal::Transaction.create('1', {}) }
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
      subject { transaction.send(:cleaned_backtrace, ['line 1']) }

      it { should == ['line 1'] }

      pending "calls Rails backtrace cleaner if Rails is present"
    end
  end
end
