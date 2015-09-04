require 'spec_helper'

begin
  require 'sinatra'
rescue LoadError
end

if defined?(::Sinatra)
  describe Appsignal::Rack::SinatraInstrumentation do
    before :all do
      start_agent
      @events = []
      @subscriber = ActiveSupport::Notifications.subscribe do |*args|
        @events << ActiveSupport::Notifications::Event.new(*args)
      end
    end
    after :all do
      ActiveSupport::Notifications.unsubscribe(@subscriber)
    end

    let(:app) { double(:call => true) }
    let(:env) { {} }
    let(:middleware) { Appsignal::Rack::SinatraInstrumentation.new(app, {}) }

    describe "#call" do
     before do
       middleware.stub(:raw_payload => {})
     end

      context "when appsignal is active" do
        before { Appsignal.stub(:active? => true) }

        it "should call with monitoring" do
          expect( middleware ).to receive(:call_with_appsignal_monitoring).with(env)
        end
      end

      context "when appsignal is not active" do
        before { Appsignal.stub(:active? => false) }

        it "should not call with monitoring" do
          expect( middleware ).to_not receive(:call_with_appsignal_monitoring)
        end

        it "should call the stack" do
          expect( app ).to receive(:call).with(env)
        end
      end

      after { middleware.call(env) }
    end

    describe "#call_with_appsignal_monitoring" do
      before do
        middleware.stub(:raw_payload => {})
        env['sinatra.route'] = 'GET /'
      end

      it "should instrument the call" do
        app.should_receive(:call).with(env)

        middleware.call_with_appsignal_monitoring(env)

        process_action_event = @events.last
        process_action_event.name.should == 'process_action.sinatra'
        process_action_event.payload[:action].should == 'GET /'
      end

      it "should still set the action if there was an exception" do
        app.should_receive(:call).with(env).and_raise('the roof')

        lambda {
          middleware.call_with_appsignal_monitoring(env)
        }.should raise_error

        process_action_event = @events.last
        process_action_event.name.should == 'process_action.sinatra'
        process_action_event.payload[:action].should == 'GET /'
      end

      it "should add exceptions stored in env under sinatra.error" do
        exception = RuntimeError.new('Raise the roof')
        env['sinatra.error'] = exception

        transaction = double
        transaction.stub(:set_process_action_event)
        transaction.stub(:add_event)
        Appsignal.should_receive(:add_exception).with(exception)
        Appsignal::Transaction.stub(:current => transaction)

        middleware.call_with_appsignal_monitoring(env)
      end
    end

    describe "raw_payload" do
      let(:env) do
        {
          'rack.input' => StringIO.new,
          'REQUEST_METHOD' => 'GET',
          'PATH_INFO' => '/homepage',
          'QUERY_STRING' => 'param=something'
        }
      end
      subject { middleware.raw_payload(env) }

      it { should == {
        :params => {'param' => 'something'},
        :session => {},
        :method => 'GET',
        :path => '/homepage'
      } }
    end

    describe "use a custom request class and parameters method" do
      let(:request_class) do
        double(
          new: double(
            request_method: 'POST',
            path: '/somewhere',
            filtered_params: {'param' => 'changed_something'}
          )
        )
      end
      let(:options) do
        { request_class: request_class, params_method: :filtered_params }
      end
      let(:middleware) { Appsignal::Rack::Instrumentation.new(app, options) }
      subject { middleware.raw_payload(env) }

      it { should == {
        :action => 'POST:/somewhere',
        :params => {'param' => 'changed_something'},
        :method => 'POST',
        :path => '/somewhere'
      } }
    end
  end
end
