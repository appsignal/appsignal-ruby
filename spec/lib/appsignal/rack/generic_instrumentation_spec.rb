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

      expect(last_transaction.to_h).to include(
        "events" => [
          hash_including(
            "body" => "",
            "body_format" => Appsignal::EventFormatter::DEFAULT,
            "count" => 1,
            "name" => "process_action.generic",
            "title" => ""
          )
        ]
      )
    end
  end

  context "without action name metadata" do
    it "reports 'unknown' as the action name" do
      make_request(env)

      expect(last_transaction.to_h).to include("action" => "unknown")
    end
  end
end
