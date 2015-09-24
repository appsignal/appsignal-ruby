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

  let(:time)        { Time.at(fixed_time) }
  let(:namespace)   { Appsignal::Transaction::HTTP_REQUEST }
  let(:env)         { {} }
  let(:merged_env)  { http_request_env_with_data(env) }
  let(:options)     { {} }
  let(:request)     { Rack::Request.new(merged_env) }
  let(:transaction) { Appsignal::Transaction.create('1', namespace, request, options) }

  before { Timecop.freeze(time) }
  after  { Timecop.return }

  context "class methods" do
    describe ".create" do
      subject { transaction }

      it "should add the transaction to thread local" do
        Appsignal::Extension.should_receive(:start_transaction).with('1', 'http_request')
        subject
        Thread.current[:appsignal_transaction].should == subject
      end

      it "should create a transaction" do
        subject.should be_a Appsignal::Transaction
        subject.transaction_id.should == '1'
        subject.namespace.should == 'http_request'
      end
    end

    describe '.current' do
      before { transaction }
      subject { Appsignal::Transaction.current }

      it 'should return the correct transaction' do
        should == transaction
      end
    end

    describe "complete_current!" do
      before { Thread.current[:appsignal_transaction] = nil }

      context "with a current transaction" do
        before { Appsignal::Transaction.create('2', Appsignal::Transaction::HTTP_REQUEST, {}) }

        it "should complete the current transaction and set the thread appsignal_transaction to nil" do
          Appsignal::Extension.should_receive(:finish_transaction).with(kind_of(Integer))

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

  context "pausing" do
    describe "#pause!" do
      it "should change the pause flag to true" do
        expect{
          transaction.pause!
        }.to change(transaction, :paused).from(false).to(true)
      end
    end

    describe "#resume!" do
      before { transaction.pause! }

      it "should change the pause flag to false" do
        expect{
          transaction.resume!
        }.to change(transaction, :paused).from(true).to(false)
      end
    end

    describe "#paused?" do

      it "should return the pause state" do
        expect( transaction.paused? ).to be_false
      end

      context "when paused" do
        before { transaction.pause! }

        it "should return the pause state" do
          expect( transaction.paused? ).to be_true
        end
      end
    end
  end

  context "with transaction instance" do
    context "initialization" do
      subject { transaction }

      its(:transaction_id)     { should == '1' }
      its(:namespace)          { should == 'http_request' }
      its(:transaction_index)  { should be_a Integer }
      its(:request)            { should_not be_nil }
      its(:paused)             { should be_false }
      its(:tags)               { should == {} }
      its(:transaction_index)  { should be_a Integer }

      context "options" do
        subject { transaction.options }

        its([:params_method]) { should == :params }

        context "with overridden options" do
          let(:options) { {:params_method => :filtered_params} }

          its([:params_method]) { should == :filtered_params }
        end
      end
    end

    describe "#set_tags" do
      it "should add tags to transaction" do
        expect {
          transaction.set_tags({'a' => 'b'})
        }.to change(transaction, :tags).to({'a' => 'b'})
      end
    end

    describe "set_action" do
      it "should set the action in extension" do
          Appsignal::Extension.should_receive(:set_transaction_action).with(
            kind_of(Integer),
            'PagesController#show'
          ).once

          transaction.set_action('PagesController#show')
      end

      it "should not set the action in extension when value is nil" do
        Appsignal::Extension.should_not_receive(:set_transaction_action)

        transaction.set_action(nil)
      end
    end

    describe "#set_http_or_background_action" do
      context "for a hash with controller and action" do
        let(:from) { {:controller => 'HomeController', :action => 'show'} }

        it "should set the action" do
          transaction.should_receive(:set_action).with('HomeController#show')
        end
      end

      context "for a hash with just action" do
        let(:from) { {:action => 'show'} }

        it "should set the action" do
          transaction.should_receive(:set_action).with('show')
        end
      end

      context "for a hash with class and method" do
        let(:from) { {:class => 'Worker', :method => 'perform'} }

        it "should set the action" do
          transaction.should_receive(:set_action).with('Worker#perform')
        end
      end

      after { transaction.set_http_or_background_action(from) }
    end

    describe "set_queue_start" do
      it "should set the queue start in extension" do
        Appsignal::Extension.should_receive(:set_transaction_queue_start).with(
          kind_of(Integer),
          10.0
        ).once

        transaction.set_queue_start(10.0)
      end

      it "should not set the queue start in extension when value is nil" do
        Appsignal::Extension.should_not_receive(:set_transaction_queue_start)

        transaction.set_queue_start(nil)
      end
    end

    describe "#set_http_or_background_queue_start" do
      context "for a http transaction" do
        let(:namespace) { Appsignal::Transaction::HTTP_REQUEST }
        let(:env) { {'HTTP_X_REQUEST_START' => (fixed_time * 1000).to_s} }

        it "should set the queue start on the transaction" do
          transaction.should_receive(:set_queue_start).with(13897836000)

          transaction.set_http_or_background_queue_start
        end
      end

      context "for a background transaction" do
        let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
        let(:env) { {:queue_start => fixed_time} }

        it "should set the queue start on the transaction" do
          transaction.should_receive(:set_queue_start).with(1389783600000)

          transaction.set_http_or_background_queue_start
        end
      end
    end

    describe "#set_metadata" do
      it "should set the metdata in extension" do
        Appsignal::Extension.should_receive(:set_transaction_metadata).with(
          kind_of(Integer),
          'request_method',
          'GET'
        ).once

        transaction.set_metadata('request_method', 'GET')
      end

      it "should not set the metdata in extension when value is nil" do
        Appsignal::Extension.should_not_receive(:set_transaction_metadata)

        transaction.set_metadata('request_method', nil)
      end
    end

    describe '#set_error' do
      let(:env) { http_request_env_with_data }
      let(:error) { double(:error, :message => 'test message', :backtrace => ['line 1']) }

      it "should also respond to add_exception for backwords compatibility" do
        transaction.should respond_to(:add_exception)
      end

      it "should not add the error if it's in the ignored list" do
        Appsignal.stub(:is_ignored_error? => true)
        Appsignal::Extension.should_not_receive(:set_transaction_error)

        transaction.set_error(error)
      end

      context "for a http request" do
        it "should set an error and it's data in native" do
          Appsignal::Extension.should_receive(:set_transaction_error).with(
            kind_of(Integer),
            'RSpec::Mocks::Mock',
            'test message'
          )
          Appsignal::Extension.should_receive(:set_transaction_error_data).with(
            kind_of(Integer),
            'environment',
            "{\"CONTENT_LENGTH\":\"0\",\"REQUEST_METHOD\":\"GET\",\"SERVER_NAME\":\"example.org\",\"SERVER_PORT\":\"80\",\"PATH_INFO\":\"/blog\"}"
          ).once
          Appsignal::Extension.should_receive(:set_transaction_error_data).with(
            kind_of(Integer),
            'session_data',
            "{}"
          ).once
          Appsignal::Extension.should_receive(:set_transaction_error_data).with(
            kind_of(Integer),
            'backtrace',
            "[\"line 1\"]"
          ).once
          Appsignal::Extension.should_receive(:set_transaction_error_data).with(
            kind_of(Integer),
            'params',
            '{"controller":"blog_posts","action":"show","id":"1"}'
          ).once
          Appsignal::Extension.should_receive(:set_transaction_error_data).with(
            kind_of(Integer),
            'tags',
            "{}"
          ).once

          transaction.set_error(error)
        end
      end

      context "with a non-json convertable type" do
        before do
          transaction.stub(:sanitized_params => 'a string')
        end

        it "should skip the field" do
          Appsignal::Extension.should_not_receive(:set_transaction_error_data).with(
            kind_of(Integer),
            'params',
            kind_of(String)
          )
          Appsignal::Extension.should_receive(:set_transaction_error_data).with(
            kind_of(Integer),
            kind_of(String),
            kind_of(String)
          ).exactly(4).times

          transaction.set_error(error)
        end
      end
    end

    context "generic request" do
      let(:env) { {} }
      subject { Appsignal::Transaction::GenericRequest.new(env) }

      it "should initialize with an empty env" do
        subject.env.should be_empty
      end

      context "with a filled env" do
        let(:env) do
          {
            :params => {:id => 1},
            :queue_start => 10
          }
        end

        its(:env) { should == env }
        its(:params) { should == {:id => 1} }
      end
    end

    # protected

    describe "#background_queue_start" do
      subject { transaction.send(:background_queue_start) }

      context "when queue start is nil" do
        it { should == nil }
      end

      context "when queue start is set" do
        let(:env) { background_env_with_data }

        it { should == 1389783590000 }
      end
    end

    describe "#http_queue_start" do
      let(:slightly_earlier_time) { fixed_time - 0.4 }
      let(:slightly_earlier_time_value) { (slightly_earlier_time * factor).to_i }
      subject { transaction.send(:http_queue_start) }

      shared_examples "http queue start" do
        context "when env is nil" do
          before { transaction.request.stub(:env => nil) }

          it { should be_nil }
        end

        context "with no relevant header set" do
          let(:env) { {} }

          it { should be_nil }
        end

        context "with the HTTP_X_REQUEST_START header set" do
          let(:env) { {'HTTP_X_REQUEST_START' => "t=#{slightly_earlier_time_value}"} }

          it { should == 1389783599 }

          context "with unparsable content" do
            let(:env) { {'HTTP_X_REQUEST_START' => 'something'} }

            it { should be_nil }
          end

          context "with some cruft" do
            let(:env) { {'HTTP_X_REQUEST_START' => "t=#{slightly_earlier_time_value}aaaa"} }

            it { should == 1389783599 }
          end

          context "with a really low number" do
            let(:env) { {'HTTP_X_REQUEST_START' => "t=100"} }

            it { should be_nil }
          end

          context "with the alternate HTTP_X_QUEUE_START header set" do
            let(:env) { {'HTTP_X_QUEUE_START' => "t=#{slightly_earlier_time_value}"} }

            it { should == 1389783599 }
          end
        end
      end

      context "time in miliseconds" do
        let(:factor) { 1_000 }

        it_should_behave_like "http queue start"
      end

      context "time in microseconds" do
        let(:factor) { 1_000_000 }

        it_should_behave_like "http queue start"
      end
    end

    describe "#sanitized_params" do
      subject { transaction.send(:sanitized_params) }

      context "without params" do
        before { transaction.request.stub(:params => nil) }

        it { should be_nil }
      end

      context "when not sending params" do
        before { Appsignal.config.config_hash[:send_params] = false }
        after { Appsignal.config.config_hash[:send_params] = true }

        it { should be_nil }
      end

      context "when params method does not exist" do
        let(:options) { {:params_method => :nonsense} }

        it { should be_nil }
      end

      context "with an array" do
        let(:request) { Appsignal::Transaction::GenericRequest.new(background_env_with_data(:params => ['arg1', 'arg2'])) }

        it { should == ['arg1', 'arg2'] }
      end

      context "with env" do
        it "should call the params sanitizer" do
          Appsignal::ParamsSanitizer.should_receive(:sanitize).with(kind_of(Hash)).and_return({
            'controller' => 'blog_posts',
            'action' => 'show',
            'id' => '1'
          })

          subject.should == {
            'controller' => 'blog_posts',
            'action' => 'show',
            'id' => '1'
          }
        end
      end
    end

    describe "#sanitized_environment" do
      let(:whitelisted_keys) { Appsignal::Transaction::ENV_METHODS }

      subject { transaction.send(:sanitized_environment) }

      context "when env is nil" do
        before { transaction.request.stub(:env => nil) }

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
        before { transaction.request.stub(:session => nil) }

        it { should be_nil }
      end

      context "when env is empty" do
        before { transaction.request.stub(:session => {}) }

        it { should == {} }
      end

      context "when request class does not have a session method" do
        let(:request) { Appsignal::Transaction::GenericRequest.new({}) }

        it { should be_nil }
      end

      context "when there is a session" do
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
    end

    describe '#sanitized_tags' do
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
