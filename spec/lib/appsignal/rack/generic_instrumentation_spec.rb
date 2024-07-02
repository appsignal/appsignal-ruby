describe Appsignal::Rack::GenericInstrumentation do
  let(:app) { double(:call => true) }
  let(:env) { Rack::MockRequest.env_for("/some/path") }
  let(:middleware) { Appsignal::Rack::GenericInstrumentation.new(app, {}) }

  before(:context) { start_agent }
  around { |example| keep_transactions { example.run } }

  def make_request(env)
    middleware.call(env)
  end

  context "without an exception" do
    it "reports a process_action.generic event" do
      make_request(env)

      expect(last_transaction).to include_event("name" => "process_action.generic")
    end
  end

  context "with action name env" do
    it "reports the appsignal.action env as the action name" do
      env["appsignal.action"] = "MyAction"
      make_request(env)

      expect(last_transaction).to have_action("MyAction")
    end
  end

  context "without action name metadata" do
    it "reports 'unknown' as the action name" do
      make_request(env)

      expect(last_transaction).to have_action("unknown")
    end
  end
end
