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
        expect(scope_of(root_span)).to eq(["appsignal-ruby/rack", Appsignal::VERSION])
        expect(scope_of(span)).to eq(["appsignal-ruby/rack", Appsignal::VERSION])
      end
    end

    describe "marking the transaction as an incoming HTTP request" do
      # These describe the request as a whole, so they belong on the
      # transaction's span and on none of the events recorded within it.
      it "sets the request attributes on the transaction span only", :collector_mode do
        start_collector_agent
        make_request(env)

        expect(root_span.attributes["http.request.method"]).to eq("GET")
        expect(root_span.attributes["url.path"]).to eq("/some/path")
        expect(root_span.attributes["url.scheme"]).to eq("http")
        # This request has no query string, so there is nothing to report and
        # the attribute is left out rather than sent empty.
        expect(root_span.attributes).to_not have_key("url.query")
        expect(event_spans).to_not be_empty
        event_spans.each do |span|
          expect(span.attributes).to_not have_key("http.request.method")
          expect(span.attributes).to_not have_key("url.path")
          expect(span.attributes).to_not have_key("url.scheme")
          expect(span.attributes).to_not have_key("url.query")
        end
      end

      it "reads the method off the request", :collector_mode do
        start_collector_agent
        make_request(Rack::MockRequest.env_for("/some/path", :method => "POST"))

        expect(root_span.attributes["http.request.method"]).to eq("POST")
      end

      it "reads the path, scheme and query string off the request", :collector_mode do
        start_collector_agent
        make_request(Rack::MockRequest.env_for("https://example.com/other/path?query=value"))

        # The path is the path on its own. The query string is a separate
        # attribute, so it must not end up in the path.
        expect(root_span.attributes["url.path"]).to eq("/other/path")
        expect(root_span.attributes["url.scheme"]).to eq("https")
        # Sent whole and unfiltered. The collector filters it with the
        # `filter_request_query_parameters` option.
        expect(root_span.attributes["url.query"]).to eq("query=value")
      end
    end

    describe "describing the response" do
      # The status is only known after the app has been called, by which time the
      # instrumented event has closed. That is what makes the transaction's own
      # span the one this lands on.
      it "sets the response status on the transaction span only", :collector_mode do
        start_collector_agent
        make_request(env)

        expect(root_span.attributes["http.response.status_code"]).to eq(200)
        expect(event_spans).to_not be_empty
        event_spans.each do |span|
          expect(span.attributes).to_not have_key("http.response.status_code")
        end
      end

      context "when the app responds with an error status" do
        let(:app) { DummyApp.new { |_env| [404, {}, ["Not found"]] } }

        it "reads the status off the response", :collector_mode do
          start_collector_agent
          make_request(env)

          expect(root_span.attributes["http.response.status_code"]).to eq(404)
        end
      end

      context "when the app raises" do
        let(:app) { DummyApp.new { |_env| raise ExampleException, "error" } }

        # The conventions ask for the status only when a response was sent, and
        # a request that raised never sent one.
        it "sets no response status", :collector_mode do
          start_collector_agent
          expect { make_request(env) }.to raise_error(ExampleException)

          expect(root_span.attributes).to_not have_key("http.response.status_code")
        end
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
