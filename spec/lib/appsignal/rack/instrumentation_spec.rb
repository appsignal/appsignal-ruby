require 'spec_helper'

describe Appsignal::Rack::Instrumentation do
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
  let(:middleware) { Appsignal::Rack::Instrumentation.new(app, {}) }

  describe "#call" do
    it "should instrument the call" do
      app.should_receive(:call).with(env)
      middleware.stub(:raw_payload => {})

      middleware.call(env)

      @events.last.name.should == 'process_action.rack'
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
      :action => 'GET:/homepage',
      :params => {'param' => 'something'},
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
