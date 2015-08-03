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

  describe '.create' do
    subject { Appsignal::Transaction.create('1', {}) }

    it 'should add the request id to the thread local' do
      subject
      Thread.current[:appsignal_transaction_id].should == '1'
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
    before { Thread.current[:appsignal_transaction_id] = nil }

    context "with a current transaction" do
      before { Appsignal::Transaction.create('2', {}) }

      it "should complete the current transaction and reset the thread appsignal_transaction_id" do
        Appsignal::Transaction.current.should_receive(:complete!)

        Appsignal::Transaction.complete_current!

        Thread.current[:appsignal_transaction_id].should be_nil
      end
    end

    context "without a current transaction" do
      it "should not raise an error" do
        Appsignal::Transaction.complete_current!
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

    it "should add the transaction to the list" do
      transaction
      Appsignal.transactions['3'].should == transaction
    end

    describe '#request' do
      subject { transaction.request }

      it { should be_a ::Rack::Request }
    end

    describe '#set_process_action_event' do
      before { transaction.set_process_action_event(process_action_event) }

      let(:process_action_event) { notification_event }

      it 'should add a process action event' do
        transaction.process_action_event.name.should == process_action_event.name
        transaction.process_action_event.payload.should == process_action_event.payload
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

      context "if there is no controller" do
        before do
          process_action_event.payload[:action] = 'GET /items/:id'
          process_action_event.payload.delete(:controller)
          transaction.set_process_action_event(process_action_event)
        end

        it "should set the action without a #" do
          transaction.action.should == 'GET /items/:id'
        end
      end
    end

    describe "set_perform_job_event" do
      before { transaction.set_perform_job_event(perform_job_event) }

      let(:payload) { create_background_payload }
      let(:perform_job_event) do
        notification_event(
          :name => 'perform_job.delayed_job',
          :payload => payload
        )
      end

      it 'should add a perform job event' do
        transaction.process_action_event.name.should == perform_job_event.name
        transaction.process_action_event.payload.should == perform_job_event.payload
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

    describe "#set_tags" do
      it "should add tags to transaction" do
        expect {
          transaction.set_tags({'a' => 'b'})
        }.to change(transaction, :tags).to({'a' => 'b'})
      end
    end

    describe '#add_event' do
      let(:event) { double(:event, :name => 'test') }

      it 'should add an event' do
        expect {
          transaction.add_event(event)
        }.to change(transaction, :events).to([event])
      end

      context "when paused" do
        before { transaction.pause! }

        it 'should add an event' do
          expect {
            transaction.add_event(event)
          }.to_not change(transaction, :events)
        end
      end
    end

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

    context "using exceptions" do
      let(:exception) do
        double(
          :exception,
          :class => double(:name => 'test'),
          :message   => 'Broken',
          :backtrace => [
            File.join(project_fixture_path, 'app/controllers/somethings_controller.rb:10').to_s,
            '/user/local/ruby/path.rb:8'
          ]
        )
      end

      describe '#add_exception' do
        it 'should add an exception', :if => rails_present? do
          if Gem::Version.new(Rails.version) >= Gem::Version.new('4.2.0')
            expect {
              transaction.add_exception(exception)
            }.to change(transaction, :exception).to({
              :exception => 'test',
              :message   => 'Broken',
              :backtrace => [
                'spec/support/project_fixture/app/controllers/somethings_controller.rb:10',
                '/user/local/ruby/path.rb:8'
              ]
            })
          else
            expect {
              transaction.add_exception(exception)
            }.to change(transaction, :exception).to({
              :exception => 'test',
              :message   => 'Broken',
              :backtrace => [
                'app/controllers/somethings_controller.rb:10',
                '/user/local/ruby/path.rb:8'
              ]
            })
          end
        end

        it 'should add an exception', :if => !rails_present? do
          expect {
            transaction.add_exception(exception)
          }.to change(transaction, :exception).to({
            :exception => 'test',
            :message   => 'Broken',
            :backtrace => [
              File.join(project_fixture_path, 'app/controllers/somethings_controller.rb:10'),
              '/user/local/ruby/path.rb:8'
            ]
          })
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

    describe '#slow_request?' do
      let(:start) { Time.now }
      subject { transaction.slow_request? }

      context "duration" do
        before do
          transaction.set_process_action_event(
            notification_event(:start => start, :ending => start + duration)
          )
        end

        context "when it reasonably fast" do
          let(:duration) { 0.199 } # in seconds

          it { should be_false }
        end

        context "when the request took too long" do
          let(:duration) { 0.201 } # in seconds

          it { should be_true }
        end
      end

      context "when process action event is empty" do
        before { transaction.set_process_action_event(nil) }

        it { should be_false }
      end

      context "when process action event does not have a payload" do
        let(:event) { notification_event }
        before do
          event.instance_variable_set(:@payload, nil)
          transaction.set_process_action_event(event)
        end

        it { should be_false }
      end
    end

    describe "#slower?" do
      context "comparing to a slower transaction" do
        subject { regular_transaction.slower?(slow_transaction) }

        it { should be_false }
      end

      context "comparing to a faster transaction" do
        subject { slow_transaction.slower?(regular_transaction) }

        it { should be_true }
      end
    end

    describe "clear_events!" do
      let(:transaction) { slow_transaction }

      it "should remove events from the transaction" do
        expect {
          transaction.clear_events!
        }.to change(transaction.events, :length).from(1).to(0)
      end
    end

    describe "#truncate!" do
      subject { slow_transaction }
      before  do
        subject.set_tags('a' => 'b')
        subject.sanitized_environment[:foo]  = 'bar'
        subject.sanitized_session_data[:foo] = 'bar'
        subject.sanitized_params[:foo]       = 'bar'
      end

      it "should clear the process action payload and events" do
        subject.truncate!

        subject.process_action_event.payload.should be_empty
        subject.events.should be_empty
        subject.tags.should be_empty

        subject.sanitized_environment.should be_empty
        subject.sanitized_session_data.should be_empty
        subject.sanitized_params.should be_empty

        subject.truncated?.should be_true
      end

      it "should not truncate twice" do
        subject.process_action_event.should_receive(:truncate!).once
        subject.events.should_receive(:clear).once

        subject.truncate!
        subject.truncate!
      end
    end

    describe "#convert_values_to_primitives!" do
      let(:transaction) { slow_transaction }
      let(:action_event) { transaction.process_action_event }
      let(:event) { transaction.events.first }
      let(:weird_class) { Class.new }
      let(:smash) { Smash.new.merge!(:foo => 'bar') }

      context "with values that need to be converted" do
        context "process action event payload" do
          subject { action_event.payload }
          before do
            action_event.payload.clear
            action_event.payload.merge!(
              :model => {:with => [:weird, weird_class]},
            )
            transaction.convert_values_to_primitives!
          end

          it "should convert all payloads to primitives" do
            should == {
              :model => {:with => [:weird, '#<Class>']},
            }
          end
        end

        context "payload of events" do
          subject { event.payload }
          before do
            event.payload.clear
            event.payload.merge!(
              :weird => weird_class,
              :smash => smash
              )
            transaction.convert_values_to_primitives!
          end

          its([:weird]) { should be_a(String) }
          its([:weird]) { should eql("#<Class>") }
          its([:smash]) { should == {:foo => 'bar'} }
        end
      end

      context "without values that need to be converted" do
        subject { transaction.convert_values_to_primitives! }

        it "doesn't change the action event payload" do
          before = action_event.payload.dup
          subject
          action_event.payload.should == before
        end

        it " doesn't change the event payloads" do
          before = event.payload.dup
          subject
          event.payload.should == before
        end

        it "should not covert to primitives twice" do
          transaction.convert_values_to_primitives!
          transaction.have_values_been_converted_to_primitives?.should be_true

          Appsignal::ParamsSanitizer.should_not_receive(:sanitize!)
          transaction.convert_values_to_primitives!
        end
      end
    end

    describe "#type" do
      context "with a regular transaction" do
        subject { regular_transaction.type }

        it { should == :regular_request }
      end

      context "with a slow transaction" do
        subject { slow_transaction.type }

        it { should == :slow_request }
      end

      context "with an exception transaction" do
        subject { transaction_with_exception.type }

        it { should == :exception }
      end
    end

    describe '#to_hash' do
      subject { transaction.to_hash }

      it { should be_instance_of Hash }
    end

    describe '#complete!' do
      let(:event) { double(:event) }
      let(:exception) do
        double(
          :exception,
          :class => double(:name => 'test'),
          :message   => 'Broken',
          :backtrace => [
            'app/controllers/somethings_controller.rb:10',
            '/user/local/ruby/path.rb:8'
          ]
        )
      end
      before do
        Appsignal::IPC.stub(:current => nil)
        transaction.set_process_action_event(notification_event)
      end

      it 'should remove transaction from the list' do
        expect { transaction.complete! }.
          to change(Appsignal.transactions, :length).by(-1)
      end

      context 'enqueueing' do
        context 'sanity check' do
          specify { Appsignal.should respond_to(:enqueue) }
        end

        context 'without events and without exception' do
          it 'should add transaction to the agent' do
            Appsignal.should_receive(:enqueue).with(transaction)
          end
        end

        context 'with events' do
          before { transaction.add_event(event) }

          it 'should add transaction to the agent' do
            Appsignal.should_receive(:enqueue).with(transaction)
          end
        end

        context 'with exception' do
          before { transaction.add_exception(exception) }

          it 'should add transaction to the agent' do
            Appsignal.should_receive(:enqueue).with(transaction)
          end
        end

        after { transaction.complete! }
      end

      context 'when using IPC' do
        before do
          Appsignal::IPC::Client.start
          transaction.stub(:convert_values_to_primitives! => true)
        end
        after do
          Appsignal::IPC::Client.stop
        end

        it "should convert to primitves and send itself trough the pipe" do
          transaction.should_receive(:convert_values_to_primitives!)
          Appsignal::IPC::Client.should_receive(:enqueue).with(transaction)
        end

        after { transaction.complete! }
      end
    end

    describe "#set_background_queue_start" do
      before do
        transaction.stub(:process_action_event =>
          notification_event(
            :name => 'perform_job.delayed_job',
            :payload => payload
          )
        )
        transaction.set_background_queue_start
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
      let(:slightly_earlier_time_value) { (slightly_earlier_time * factor).to_i }
      before { transaction.set_http_queue_start }
      subject { transaction.queue_start }

      shared_examples "http queue start" do
        context "without env" do
          let(:env) { nil }

          it { should be_nil }
        end

        context "with no relevant header set" do
          let(:env) { {} }

          it { should be_nil }
        end

        context "with the HTTP_X_REQUEST_START header set" do
          let(:env) { {'HTTP_X_REQUEST_START' => "t=#{slightly_earlier_time_value}"} }

          it { should == 1389783599.6 }

          context "with unparsable content" do
            let(:env) { {'HTTP_X_REQUEST_START' => 'something'} }

            it { should be_nil }
          end

          context "with some cruft" do
            let(:env) { {'HTTP_X_REQUEST_START' => "t=#{slightly_earlier_time_value}aaaa"} }

            it { should == 1389783599.6 }
          end

          context "with the alternate HTTP_X_QUEUE_START header set" do
            let(:env) { {'HTTP_X_QUEUE_START' => "t=#{slightly_earlier_time_value}"} }

            it { should == 1389783599.6 }
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

    # protected

    describe '#add_sanitized_context!' do
      subject { transaction.send(:add_sanitized_context!) }

      context "for a http request" do
        before { transaction.stub(:kind => 'http_request') }

        it "should call sanitize_environment!, sanitize_session_data! and sanitize_tags!" do
          transaction.should_receive(:sanitize_environment!)
          transaction.should_receive(:sanitize_session_data!)
          transaction.should_receive(:sanitize_tags!)
          transaction.should_receive(:sanitize_params!)
          subject
        end
      end

      context "for a non-web request" do
        before { transaction.stub(:kind => 'background_job') }

        it "should not call sanitize_session_data!" do
          transaction.should_receive(:sanitize_environment!)
          transaction.should_not_receive(:sanitize_session_data!)
          transaction.should_receive(:sanitize_tags!)
          transaction.should_receive(:sanitize_params!)
          subject
        end
      end

      specify { expect { subject }.to change(transaction, :env).to(nil) }
    end

    describe '#sanitize_environment!' do
      let(:whitelisted_keys) { Appsignal::Transaction::ENV_METHODS }
      let(:transaction) { Appsignal::Transaction.create('1', env) }
      let(:env) do
        Hash.new.tap do |hash|
          whitelisted_keys.each { |o| hash[o] = 1 } # use all whitelisted keys
          hash[:not_whitelisted] = 'I will be sanitized'
        end
      end
      subject { transaction.sanitized_environment }
      before { transaction.send(:sanitize_environment!) }

      its(:keys) { should =~ whitelisted_keys }

      context "when env is nil" do
        let(:env) { nil }

        it { should be_empty }
      end
    end

    describe '#sanitize_tags!' do
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
        transaction.send(:sanitize_tags!)
      end
      subject { transaction.tags.keys }

      it "should only return whitelisted data" do
        should =~ [
          :valid_key,
          'valid_string_key',
          :both_symbols,
          :integer_value
        ]
      end
    end

    describe '#sanitize_session_data!' do
      subject { transaction.send(:sanitize_session_data!) }
      before do
        transaction.should respond_to(:request)
        transaction.stub_chain(:request, :session => {:foo => :bar})
        transaction.stub_chain(:request, :fullpath => :bar)
      end

      it "passes the session data into the params sanitizer" do
        Appsignal::ParamsSanitizer.should_receive(:sanitize).with({:foo => :bar}).
          and_return(:sanitized_foo)
        subject
        transaction.sanitized_session_data.should == :sanitized_foo
      end

      it "sets the fullpath of the request" do
        expect { subject }.to change(transaction, :fullpath).to(:bar)
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
          subject
          transaction.sanitized_session_data.should == {}
        end
      end
    end

    describe '#sanitize_params!' do
      let(:params) { {:foo => 'bar'} }
      let(:transaction) do
        Appsignal::Transaction.create('1', {}, :params => params)
      end
      before  { Appsignal.config = {:send_params => true} }
      subject { transaction.sanitized_params }

      it "should call the params sanitizer and set sanitized params" do
        Appsignal::ParamsSanitizer.should_receive(:sanitize)
          .with(params)
          .and_return({'foo' => 'bar'})

        transaction.send(:sanitize_params!)

        should == {'foo' => 'bar'}
      end

      context "when skipping session data" do
        before { Appsignal.config = {:send_params => false} }

        it "should not pass data to the params sanitizer" do
          Appsignal::ParamsSanitizer.should_not_receive(:sanitize)
          transaction.send(:sanitize_params!)

          should == {}
        end
      end
    end
  end
end
