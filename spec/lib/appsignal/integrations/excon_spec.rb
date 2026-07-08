if DependencyHelper.excon_present?
  require "excon"
  require "appsignal/integrations/excon"
  require "appsignal/integrations/excon/appsignal_middleware"

  # Integration test against the real Excon gem (the hooks/excon_spec.rb suite
  # stubs Excon). Verifies, end to end, that the inject-only middleware writes
  # trace context onto a live outgoing request while the instrumentor's client
  # event span is current -- the ordering the stubbed suite can't prove.
  describe "Excon integration" do
    before { Appsignal::Hooks::ExconHook.new.install }

    describe "a GET request" do
      def perform
        stub_request(:get, "http://www.example.com/")
        Excon.get("http://www.example.com/")
      end

      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform

        expect(transaction).to include_event(
          "name" => "request.excon",
          "title" => "GET http://www.example.com"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        span = event_spans.find { |s| s.attributes["appsignal.category"] == "request.excon" }
        expect(span).not_to be_nil
        expect(span.kind).to eq(:client)
        expect(span.parent_span_id).to eq(root_span.span_id)

        # The injected traceparent must reflect the Excon CLIENT event span, not
        # the root span -- proving the middleware runs inside the instrumentor's
        # event span on a real request.
        expect(injected_traceparent("http://www.example.com/"))
          .to eq("00-#{span.hex_trace_id}-#{span.hex_span_id}-01")
      end
    end

    # Reads the `traceparent` header off the recorded outgoing request to `url`.
    def injected_traceparent(url)
      traceparent = nil
      expect(
        a_request(:get, url).with { |request| traceparent = request.headers["Traceparent"] }
      ).to have_been_made
      traceparent
    end
  end
end
