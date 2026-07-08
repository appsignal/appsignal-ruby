describe Appsignal::Rack::InstrumentationMiddleware do
  let(:app) { DummyApp.new }
  let(:env) { Rack::MockRequest.env_for("/some/path") }
  let(:middleware) { described_class.new(app, {}) }

  def make_request(env)
    middleware.call(env)
  end

  context "without an exception" do
    describe "reports a process_request_middleware.rack event" do
      def perform
        make_request(env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to include_event("name" => "process_request_middleware.rack")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(event_spans.map(&:name)).to include("process_request_middleware.rack")
        expect(root_span.kind).to eq(:server)
        span = event_spans.find { |s| s.name == "process_request_middleware.rack" }
        expect(span).not_to be_nil
        expect(span.parent_span_id).to eq(root_span.span_id)
      end
    end
  end

  context "with custom action name" do
    let(:app) { DummyApp.new { |_env| Appsignal.set_action("MyAction") } }

    describe "reports the custom action name" do
      def perform
        make_request(env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to have_action("MyAction")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(root_span.name).to eq("MyAction")
        expect(root_span.attributes["appsignal.action_name"]).to eq("MyAction")
      end
    end
  end

  context "without action name metadata" do
    describe "reports no action name" do
      def perform
        make_request(env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to_not have_action
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(root_span.attributes).to_not have_key("appsignal.action_name")
      end
    end
  end
end
