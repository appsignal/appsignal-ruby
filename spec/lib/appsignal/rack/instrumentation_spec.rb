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
        'REQUEST_METHOD' => 'GET',
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
end
