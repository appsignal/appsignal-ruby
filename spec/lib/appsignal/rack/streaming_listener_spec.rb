require "appsignal/rack/streaming_listener"

describe Appsignal::Rack::StreamingListener do
  let(:env) { {} }
  let(:app) { DummyApp.new }
  let(:middleware) { described_class.new(app, {}) }
  before { start_agent }
  around { |example| keep_transactions { example.run } }

  def make_request
    middleware.call(env)
  end

  it "instruments the call" do
    make_request

    expect(last_transaction).to include_event("name" => "process_streaming_request.rack")
  end

  it "set no action by default" do
    make_request

    expect(last_transaction).to_not have_action
  end

  it "set `appsignal.action` to the action name" do
    env["appsignal.action"] = "Action"

    make_request

    expect(last_transaction).to have_action("Action")
  end
end
