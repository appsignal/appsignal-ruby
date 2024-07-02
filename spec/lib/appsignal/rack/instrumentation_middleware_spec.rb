describe Appsignal::Rack::InstrumentationMiddleware do
  let(:app) { DummyApp.new }
  let(:env) { Rack::MockRequest.env_for("/some/path") }
  let(:middleware) { described_class.new(app, {}) }

  before { start_agent }
  around { |example| keep_transactions { example.run } }

  def make_request(env)
    middleware.call(env)
  end

  context "without an exception" do
    it "reports a process_request_middleware.rack event" do
      make_request(env)

      expect(last_transaction).to include_event("name" => "process_request_middleware.rack")
    end
  end

  context "with custom action name" do
    let(:app) { DummyApp.new { |_env| Appsignal.set_action("MyAction") } }

    it "reports the custom action name" do
      make_request(env)

      expect(last_transaction).to have_action("MyAction")
    end
  end

  context "without action name metadata" do
    it "reports no action name" do
      make_request(env)

      expect(last_transaction).to_not have_action
    end
  end
end
