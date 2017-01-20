require_relative "../../support/mocks/fake_gc_profiler"

class Smash < Hash
  def []=(_key, _val)
    raise "the roof"
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
  let(:transaction) { Appsignal::Transaction.new("1", namespace, request, options) }

  before { Timecop.freeze(time) }
  after  { Timecop.return }

  describe "class methods" do
    describe ".create" do
      it "should add the transaction to thread local" do
        expect(Appsignal::Extension).to receive(:start_transaction).with("1", "http_request", 0)

        created_transaction = Appsignal::Transaction.create("1", namespace, request, options)

        expect(Thread.current[:appsignal_transaction]).to eq created_transaction
      end

      it "should create a transaction" do
        created_transaction = Appsignal::Transaction.create("1", namespace, request, options)

        expect(created_transaction).to be_a Appsignal::Transaction
        expect(created_transaction.transaction_id).to eq "1"
        expect(created_transaction.namespace).to eq "http_request"
      end

      context "when a transaction is already running" do
        let(:running_transaction) { double(:transaction_id => 2) }
        before { Thread.current[:appsignal_transaction] = running_transaction }

        it "should not create a new transaction" do
          expect(
            Appsignal::Transaction.create("1", namespace, request, options)
          ).to eq(running_transaction)
        end

        it "should output a debug message" do
          expect(Appsignal.logger).to receive(:debug)
            .with("Trying to start new transaction 1 but 2 is already running. Using 2")

          Appsignal::Transaction.create("1", namespace, request, options)
        end

        context "with option to force a new transaction" do
          let(:options) { { :force => true } }
          it "should not create a new transaction" do
            expect(
              Appsignal::Transaction.create("1", namespace, request, options)
            ).to_not eq(running_transaction)
          end
        end
      end
    end

    describe ".current" do
      before { Thread.current[:appsignal_transaction] = transaction }

      subject { Appsignal::Transaction.current }

      context "if there is a transaction" do
        before { Appsignal::Transaction.create("1", namespace, request, options) }

        it "should return the correct transaction" do
          is_expected.to eq transaction
        end

        it "should indicate it's not a nil transaction" do
          expect(subject.nil_transaction?).to be_falsy
        end
      end

      context "if there is no transaction" do
        before do
          Thread.current[:appsignal_transaction] = nil
        end

        it "should return a nil transaction stub" do
          is_expected.to be_a Appsignal::Transaction::NilTransaction
        end

        it "should indicate it's a nil transaction" do
          expect(subject.nil_transaction?).to be_truthy
        end
      end
    end

    describe "complete_current!" do
      before { Appsignal::Transaction.create("2", Appsignal::Transaction::HTTP_REQUEST, {}) }

      it "should complete the current transaction and set the thread appsignal_transaction to nil" do
        expect(Appsignal::Transaction.current).to receive(:complete)

        Appsignal::Transaction.complete_current!

        expect(Thread.current[:appsignal_transaction]).to be_nil
      end

      it "should still clear the transaction if there is an error" do
        expect(Appsignal::Transaction.current).to receive(:complete).and_raise "Error"

        Appsignal::Transaction.complete_current!

        expect(Thread.current[:appsignal_transaction]).to be_nil
      end

      context "if a transaction is discarded" do
        it "should not complete the transaction" do
          expect(Appsignal::Transaction.current.ext).to_not receive(:complete)

          Appsignal::Transaction.current.discard!
          expect(Appsignal::Transaction.current.discarded?).to be_truthy

          Appsignal::Transaction.complete_current!

          expect(Thread.current[:appsignal_transaction]).to be_nil
        end

        it "should not be discarded when restore! is called" do
          Appsignal::Transaction.current.discard!
          expect(Appsignal::Transaction.current.discarded?).to be_truthy
          Appsignal::Transaction.current.restore!
          expect(Appsignal::Transaction.current.discarded?).to be_falsy
        end
      end
    end
  end

  describe "#complete" do
    it "should sample data if it needs to be sampled" do
      expect(transaction.ext).to receive(:finish).and_return(true)
      expect(transaction).to receive(:sample_data)
      expect(transaction.ext).to receive(:complete)

      transaction.complete
    end

    it "should not sample data if it does not need to be sampled" do
      expect(transaction.ext).to receive(:finish).and_return(false)
      expect(transaction).to_not receive(:sample_data)
      expect(transaction.ext).to receive(:complete)

      transaction.complete
    end
  end

  context "pausing" do
    describe "#pause!" do
      it "should change the pause flag to true" do
        expect do
          transaction.pause!
        end.to change(transaction, :paused).from(false).to(true)
      end
    end

    describe "#resume!" do
      before { transaction.pause! }

      it "should change the pause flag to false" do
        expect do
          transaction.resume!
        end.to change(transaction, :paused).from(true).to(false)
      end
    end

    describe "#paused?" do
      it "should return the pause state" do
        expect(transaction.paused?).to be_falsy
      end

      context "when paused" do
        before { transaction.pause! }

        it "should return the pause state" do
          expect(transaction.paused?).to be_truthy
        end
      end
    end
  end

  context "with transaction instance" do
    context "initialization" do
      it "loads the AppSignal extension" do
        expect(transaction.ext).to_not be_nil
      end

      it "sets the transaction id" do
        expect(transaction.transaction_id).to eq "1"
      end

      it "sets the namespace to http_request" do
        expect(transaction.namespace).to eq "http_request"
      end

      it "sets the request" do
        expect(transaction.request).to_not be_nil
      end

      it "sets the request not to paused" do
        expect(transaction.paused).to be_falsy
      end

      it "sets no tags by default" do
        expect(transaction.tags).to eq({})
      end

      describe "#options" do
        subject { transaction.options }

        it "sets the default :params_method" do
          expect(subject[:params_method]).to eq :params
        end

        context "with overridden options" do
          let(:options) { { :params_method => :filtered_params } }

          it "sets the overriden :params_method" do
            expect(subject[:params_method]).to eq :filtered_params
          end
        end
      end
    end

    describe "#store" do
      it "should return an empty store when it's not already present" do
        expect(transaction.store("test")).to eql({})
      end

      it "should store changes to the store" do
        transaction_store = transaction.store("test")
        transaction_store["transaction"] = "value"

        expect(transaction.store("test")).to eql("transaction" => "value")
      end
    end

    describe "#set_tags" do
      it "should add tags to transaction" do
        expect do
          transaction.set_tags("a" => "b")
        end.to change(transaction, :tags).to("a" => "b")
      end
    end

    describe "set_action" do
      it "should set the action in extension" do
        expect(transaction.ext).to receive(:set_action).with(
          "PagesController#show"
        ).once

        transaction.set_action("PagesController#show")
      end

      it "should not set the action in extension when value is nil" do
        expect(Appsignal::Extension).to_not receive(:set_transaction_action)

        transaction.set_action(nil)
      end
    end

    describe "#set_http_or_background_action" do
      context "for a hash with controller and action" do
        let(:from) { { :controller => "HomeController", :action => "show" } }

        it "should set the action" do
          expect(transaction).to receive(:set_action).with("HomeController#show")
        end
      end

      context "for a hash with just action" do
        let(:from) { { :action => "show" } }

        it "should set the action" do
          expect(transaction).to receive(:set_action).with("show")
        end
      end

      context "for a hash with class and method" do
        let(:from) { { :class => "Worker", :method => "perform" } }

        it "should set the action" do
          expect(transaction).to receive(:set_action).with("Worker#perform")
        end
      end

      after { transaction.set_http_or_background_action(from) }
    end

    describe "set_queue_start" do
      it "should set the queue start in extension" do
        expect(transaction.ext).to receive(:set_queue_start).with(
          10.0
        ).once

        transaction.set_queue_start(10.0)
      end

      it "should not set the queue start in extension when value is nil" do
        expect(transaction.ext).to_not receive(:set_queue_start)

        transaction.set_queue_start(nil)
      end

      it "should not raise an error when the queue start is too big" do
        expect(transaction.ext).to receive(:set_queue_start).and_raise(RangeError)

        expect(Appsignal.logger).to receive(:warn).with("Queue start value 10 is too big")

        expect do
          transaction.set_queue_start(10)
        end.to_not raise_error
      end
    end

    describe "#set_http_or_background_queue_start" do
      context "for a http transaction" do
        let(:namespace) { Appsignal::Transaction::HTTP_REQUEST }
        let(:env) { { "HTTP_X_REQUEST_START" => (fixed_time * 1000).to_s } }

        it "should set the queue start on the transaction" do
          expect(transaction).to receive(:set_queue_start).with(13_897_836_000)

          transaction.set_http_or_background_queue_start
        end
      end

      context "for a background transaction" do
        let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
        let(:env) { { :queue_start => fixed_time } }

        it "should set the queue start on the transaction" do
          expect(transaction).to receive(:set_queue_start).with(1_389_783_600_000)

          transaction.set_http_or_background_queue_start
        end
      end
    end

    describe "#set_metadata" do
      it "should set the metdata in extension" do
        expect(transaction.ext).to receive(:set_metadata).with(
          "request_method",
          "GET"
        ).once

        transaction.set_metadata("request_method", "GET")
      end

      it "should not set the metdata in extension when value is nil" do
        expect(transaction.ext).to_not receive(:set_metadata)

        transaction.set_metadata("request_method", nil)
      end
    end

    describe "set_sample_data" do
      it "should set the data" do
        expect(transaction.ext).to receive(:set_sample_data).with(
          "params",
          Appsignal::Utils.data_generate("controller" => "blog_posts", "action" => "show", "id" => "1")
        ).once

        transaction.set_sample_data(
          "params",
          :controller => "blog_posts",
          :action     => "show",
          :id         => "1"
        )
      end

      it "should do nothing if the data cannot be converted to json" do
        expect(transaction.ext).to_not receive(:set_sample_data).with(
          "params",
          kind_of(String)
        )

        transaction.set_sample_data("params", "string")
      end
    end

    describe "#sample_data" do
      it "should sample data" do
        expect(transaction.ext).to receive(:set_sample_data).with(
          "environment",
          Appsignal::Utils.data_generate(
            "CONTENT_LENGTH" => "0",
            "REQUEST_METHOD" => "GET",
            "SERVER_NAME" => "example.org",
            "SERVER_PORT" => "80",
            "PATH_INFO" => "/blog"
          )
        ).once
        expect(transaction.ext).to receive(:set_sample_data).with(
          "session_data",
          Appsignal::Utils.data_generate({})
        ).once
        expect(transaction.ext).to receive(:set_sample_data).with(
          "params",
          Appsignal::Utils.data_generate("controller" => "blog_posts", "action" => "show", "id" => "1")
        ).once
        expect(transaction.ext).to receive(:set_sample_data).with(
          "metadata",
          Appsignal::Utils.data_generate("key" => "value")
        ).once
        expect(transaction.ext).to receive(:set_sample_data).with(
          "tags",
          Appsignal::Utils.data_generate({})
        ).once

        transaction.sample_data
      end
    end

    describe "#set_error" do
      let(:env) { http_request_env_with_data }
      let(:error) { double(:error, :message => "test message", :backtrace => ["line 1"]) }

      it "should also respond to add_exception for backwords compatibility" do
        expect(transaction).to respond_to(:add_exception)
      end

      it "should not add the error if appsignal is not active" do
        allow(Appsignal).to receive(:active?).and_return(false)
        expect(transaction.ext).to_not receive(:set_error)

        transaction.set_error(error)
      end

      context "for a http request" do
        it "should set an error in the extension" do
          expect(transaction.ext).to receive(:set_error).with(
            "RSpec::Mocks::Double",
            "test message",
            Appsignal::Utils.data_generate(["line 1"])
          )

          transaction.set_error(error)
        end
      end

      context "when error message is nil" do
        let(:error) { double(:error, :message => nil, :backtrace => ["line 1"]) }

        it "should not raise an error" do
          expect { transaction.set_error(error) }.to_not raise_error
        end

        it "should set an error in the extension" do
          expect(transaction.ext).to receive(:set_error).with(
            "RSpec::Mocks::Double",
            "",
            Appsignal::Utils.data_generate(["line 1"])
          )

          transaction.set_error(error)
        end
      end
    end

    describe "#start_event" do
      it "should start the event in the extension" do
        expect(transaction.ext).to receive(:start_event)

        transaction.start_event
      end
    end

    describe "#finish_event" do
      it "should finish the event in the extension" do
        expect(transaction.ext).to receive(:finish_event).with(
          "name",
          "title",
          "body",
          1,
          0
        )

        transaction.finish_event(
          "name",
          "title",
          "body",
          1
        )
      end

      it "should finish the event in the extension with nil arguments" do
        expect(transaction.ext).to receive(:finish_event).with(
          "name",
          "",
          "",
          0,
          0
        )

        transaction.finish_event(
          "name",
          nil,
          nil,
          nil
        )
      end

      it "should add garbage collection time" do
        allow_any_instance_of(Appsignal::GarbageCollectionProfiler)
          .to receive(:internal_profiler)
          .and_return(FakeGCProfiler.new(0.12345))

        transaction.finish_event("name", nil, nil, nil)
      end
    end

    describe "#record_event" do
      it "should record the event in the extension" do
        expect(transaction.ext).to receive(:record_event).with(
          "name",
          "title",
          "body",
          1000,
          1
        )

        transaction.record_event(
          "name",
          "title",
          "body",
          1000,
          1
        )
      end

      it "should finish the event in the extension with nil arguments" do
        expect(transaction.ext).to receive(:record_event).with(
          "name",
          "",
          "",
          1000,
          0
        )

        transaction.record_event(
          "name",
          nil,
          nil,
          1000,
          nil
        )
      end
    end

    describe "#instrument" do
      it "should start and finish an event around the given block" do
        stub = double
        expect(stub).to receive(:method_call).and_return("return value")

        expect(transaction).to receive(:start_event)
        expect(transaction).to receive(:finish_event).with(
          "name",
          "title",
          "body",
          0
        )

        return_value = transaction.instrument "name", "title", "body" do
          stub.method_call
        end
        expect(return_value).to eq "return value"
      end
    end

    context "generic request" do
      let(:env) { {} }
      subject { Appsignal::Transaction::GenericRequest.new(env) }

      it "initializes with an empty env" do
        expect(subject.env).to be_empty
      end

      context "when given an env" do
        let(:env) do
          {
            :params => { :id => 1 },
            :queue_start => 10
          }
        end

        it "sets the given env" do
          expect(subject.env).to eq env
        end

        it "sets the params present in the env" do
          expect(subject.params).to eq(:id => 1)
        end
      end
    end

    # protected

    describe "#background_queue_start" do
      subject { transaction.send(:background_queue_start) }

      context "when request is nil" do
        let(:request) { nil }

        it { is_expected.to eq nil }
      end

      context "when env is nil" do
        before { expect(transaction.request).to receive(:env).and_return(nil) }

        it { is_expected.to eq nil }
      end

      context "when queue start is nil" do
        it { is_expected.to eq nil }
      end

      context "when queue start is set" do
        let(:env) { background_env_with_data }

        it { is_expected.to eq 1_389_783_590_000 }
      end
    end

    describe "#http_queue_start" do
      let(:slightly_earlier_time) { fixed_time - 0.4 }
      let(:slightly_earlier_time_value) { (slightly_earlier_time * factor).to_i }
      subject { transaction.send(:http_queue_start) }

      shared_examples "http queue start" do
        context "when request is nil" do
          let(:request) { nil }

          it { is_expected.to be_nil }
        end

        context "when env is nil" do
          before { expect(transaction.request).to receive(:env).and_return(nil) }

          it { is_expected.to be_nil }
        end

        context "with no relevant header set" do
          let(:env) { {} }

          it { is_expected.to be_nil }
        end

        context "with the HTTP_X_REQUEST_START header set" do
          let(:env) { { "HTTP_X_REQUEST_START" => "t=#{slightly_earlier_time_value}" } }

          it { is_expected.to eq 1_389_783_599_600 }

          context "with unparsable content" do
            let(:env) { { "HTTP_X_REQUEST_START" => "something" } }

            it { is_expected.to be_nil }
          end

          context "with some cruft" do
            let(:env) { { "HTTP_X_REQUEST_START" => "t=#{slightly_earlier_time_value}aaaa" } }

            it { is_expected.to eq 1_389_783_599_600 }
          end

          context "with a really low number" do
            let(:env) { { "HTTP_X_REQUEST_START" => "t=100" } }

            it { is_expected.to be_nil }
          end

          context "with the alternate HTTP_X_QUEUE_START header set" do
            let(:env) { { "HTTP_X_QUEUE_START" => "t=#{slightly_earlier_time_value}" } }

            it { is_expected.to eq 1_389_783_599_600 }
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
        before { allow(transaction.request).to receive(:params).and_return(nil) }

        it { is_expected.to be_nil }
      end

      context "when params crashes" do
        before { allow(transaction.request).to receive(:params).and_raise(NoMethodError) }

        it { is_expected.to be_nil }
      end

      context "when params method does not exist" do
        let(:options) { { :params_method => :nonsense } }

        it { is_expected.to be_nil }
      end

      context "when not sending params" do
        before { Appsignal.config.config_hash[:send_params] = false }
        after { Appsignal.config.config_hash[:send_params] = true }

        it { is_expected.to be_nil }
      end

      context "with an array" do
        let(:request) do
          Appsignal::Transaction::GenericRequest.new(background_env_with_data(:params => ["arg1", "arg2"]))
        end

        it { is_expected.to eq ["arg1", "arg2"] }

        context "with AppSignal filtering" do
          before { Appsignal.config.config_hash[:filter_parameters] = %w(foo) }
          after { Appsignal.config.config_hash[:filter_parameters] = [] }

          it { is_expected.to eq ["arg1", "arg2"] }
        end
      end

      context "with env" do
        context "with sanitization" do
          let(:request) do
            Appsignal::Transaction::GenericRequest.new \
              http_request_env_with_data(:params => { :foo => :bar })
          end

          it "should call the params sanitizer" do
            puts Appsignal.config.config_hash[:filter_parameters].inspect
            expect(subject).to eq(:foo => :bar)
          end
        end

        context "with AppSignal filtering" do
          let(:request) do
            Appsignal::Transaction::GenericRequest.new \
              http_request_env_with_data(:params => { :foo => :bar, :baz => :bat })
          end
          before { Appsignal.config.config_hash[:filter_parameters] = %w(foo) }
          after { Appsignal.config.config_hash[:filter_parameters] = [] }

          it "should call the params sanitizer with filtering" do
            expect(subject).to eq(:foo => "[FILTERED]", :baz => :bat)
          end
        end
      end
    end

    describe "#sanitized_environment" do
      let(:whitelisted_keys) { Appsignal::Transaction::ENV_METHODS }

      subject { transaction.send(:sanitized_environment) }

      context "when request is nil" do
        let(:request) { nil }

        it { is_expected.to be_nil }
      end

      context "when env is nil" do
        before { expect(transaction.request).to receive(:env).and_return(nil) }

        it { is_expected.to be_nil }
      end

      context "when env is present" do
        let(:env) do
          {}.tap do |hash|
            whitelisted_keys.each { |o| hash[o] = 1 } # use all whitelisted keys
            hash[whitelisted_keys] = nil # don't add if nil
            hash[:not_whitelisted] = "I will be sanitized"
          end
        end

        it "only sets whitelisted keys" do
          expect(subject.keys).to match_array(whitelisted_keys)
        end
      end
    end

    describe "#sanitized_session_data" do
      subject { transaction.send(:sanitized_session_data) }

      context "when request is nil" do
        let(:request) { nil }

        it { is_expected.to be_nil }
      end

      context "when session is nil" do
        before { expect(transaction.request).to receive(:session).and_return(nil) }

        it { is_expected.to be_nil }
      end

      context "when session is empty" do
        before { expect(transaction.request).to receive(:session).and_return({}) }

        it { is_expected.to eq({}) }
      end

      context "when request class does not have a session method" do
        let(:request) { Appsignal::Transaction::GenericRequest.new({}) }

        it { is_expected.to be_nil }
      end

      context "when there is a session" do
        before do
          expect(transaction).to respond_to(:request)
          transaction.stub_chain(:request, :session => { :foo => :bar })
          transaction.stub_chain(:request, :fullpath => :bar)
        end

        it "passes the session data into the params sanitizer" do
          expect(Appsignal::Utils::ParamsSanitizer).to receive(:sanitize).with(:foo => :bar)
            .and_return(:sanitized_foo)
          expect(subject).to eq :sanitized_foo
        end

        if defined? ActionDispatch::Request::Session
          context "with ActionDispatch::Request::Session" do
            before do
              expect(transaction).to respond_to(:request)
              transaction.stub_chain(:request, :session => action_dispatch_session)
              transaction.stub_chain(:request, :fullpath => :bar)
            end

            it "should return an session hash" do
              expect(Appsignal::Utils::ParamsSanitizer).to receive(:sanitize).with("foo" => :bar)
                .and_return(:sanitized_foo)
              subject
            end

            def action_dispatch_session
              store = Class.new do
                def load_session(_env)
                  [1, { :foo => :bar }]
                end

                def session_exists?(_env)
                  true
                end
              end.new
              ActionDispatch::Request::Session.create(store, ActionDispatch::Request.new("rack.input" => StringIO.new), {})
            end
          end
        end

        context "when skipping session data" do
          before do
            Appsignal.config = { :skip_session_data => true }
          end

          it "does not pass the session data into the params sanitizer" do
            expect(Appsignal::Utils::ParamsSanitizer).to_not receive(:sanitize)
            expect(subject).to be_nil
          end
        end
      end
    end

    describe "#metadata" do
      subject { transaction.send(:metadata) }

      context "when request is nil" do
        let(:request) { nil }

        it { is_expected.to be_nil }
      end

      context "when env is nil" do
        before { expect(transaction.request).to receive(:env).and_return(nil) }

        it { is_expected.to be_nil }
      end

      context "when env is present" do
        let(:env) { { :metadata => { :key => "value" } } }

        it { is_expected.to eq env[:metadata] }
      end
    end

    describe "#sanitized_tags" do
      before do
        transaction.set_tags(
          :valid_key => "valid_value",
          "valid_string_key" => "valid_value",
          :both_symbols => :valid_value,
          :integer_value => 1,
          :hash_value => { "invalid" => "hash" },
          :array_value => ["invalid", "array"],
          :to_long_value => SecureRandom.urlsafe_base64(101),
          :object => Object.new,
          SecureRandom.urlsafe_base64(101) => "to_long_key"
        )
      end
      subject { transaction.send(:sanitized_tags).keys }

      it "should only return whitelisted data" do
        is_expected.to match_array([
          :valid_key,
          "valid_string_key",
          :both_symbols,
          :integer_value
        ])
      end
    end

    describe "#cleaned_backtrace" do
      subject { transaction.send(:cleaned_backtrace, ["line 1", "line 2"]) }

      it "returns the backtrace" do
        expect(subject).to eq ["line 1", "line 2"]
      end

      if rails_present?
        context "with rails" do
          it "cleans the backtrace with the Rails backtrace cleaner" do
            ::Rails.backtrace_cleaner.add_filter do |line|
              line.tr("2", "?")
            end
            expect(subject).to eq ["line 1", "line ?"]
          end
        end
      end
    end
  end

  describe Appsignal::Transaction::NilTransaction do
    subject { Appsignal::Transaction::NilTransaction.new }

    it "should have method stubs" do
      expect do
        subject.complete
        subject.pause!
        subject.resume!
        subject.paused?
        subject.store(:key)
        subject.set_tags(:tag => 1)
        subject.set_action("action")
        subject.set_http_or_background_action
        subject.set_queue_start(1)
        subject.set_http_or_background_queue_start
        subject.set_metadata("key", "value")
        subject.set_sample_data("key", "data")
        subject.sample_data
        subject.set_error("a")
      end.to_not raise_error
    end
  end
end
