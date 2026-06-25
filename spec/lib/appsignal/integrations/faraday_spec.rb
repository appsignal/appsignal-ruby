if DependencyHelper.faraday_present?
  require "faraday"
  require "appsignal/integrations/faraday"

  # Integration test against the real Faraday gem. The hook auto-installs, onto
  # every connection, Faraday's instrumentation middleware (so the
  # `request.faraday` event fires without the user adding it) and an inject-only
  # middleware (so outgoing requests carry trace context).
  describe "Faraday integration" do
    before { Appsignal::Hooks::FaradayHook.new.install }

    # The common case: the default adapter is Net::HTTP, which AppSignal also
    # instruments. Faraday suppresses it, so the request is recorded once -- as
    # the `request.faraday` event, which also writes the `traceparent`.
    describe "a request over the default Net::HTTP adapter" do
      def perform
        stub_request(:get, "http://www.example.com/")
        Faraday.new("http://www.example.com").get("/")
      end

      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform

        # Title only, no body -- the path is left out, matching Net::HTTP.
        expect(transaction).to include_event(
          "name" => "request.faraday",
          "title" => "GET http://www.example.com",
          "body" => ""
        )
        # Net::HTTP is suppressed under Faraday, so it isn't recorded again.
        expect(transaction).to_not include_event("name" => "request.net_http")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        faraday_span = event_span("request.faraday")
        expect(faraday_span).not_to be_nil
        expect(faraday_span.kind).to eq(:client)
        expect(faraday_span.parent_span_id).to eq(root_span.span_id)

        # Net::HTTP is suppressed, so there's no nested net_http span.
        expect(event_span("request.net_http")).to be_nil

        # Faraday writes the wire traceparent (Net::HTTP doesn't run its inject).
        expect(injected_traceparent("http://www.example.com/"))
          .to eq("00-#{faraday_span.hex_trace_id}-#{faraday_span.hex_span_id}-01")
      end
    end

    # With a non-Net::HTTP adapter (here Faraday's test adapter), our inject
    # middleware is the only thing writing context, so the request carries the
    # `request.faraday` client span's traceparent -- proving the middleware runs
    # and injects inside that event's span. This is the path that gives Faraday
    # propagation for adapters AppSignal doesn't instrument directly.
    it "injects the Faraday client context on a non-Net::HTTP adapter", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)

      captured_env = nil
      connection = Faraday.new("http://www.example.com") do |faraday|
        faraday.adapter :test do |stub|
          stub.get("/") do |env|
            captured_env = env
            [200, {}, ""]
          end
        end
      end
      connection.get("/")
      Appsignal::Transaction.complete_current!

      faraday_span = event_span("request.faraday")
      expect(faraday_span).not_to be_nil
      expect(captured_env.request_headers["traceparent"])
        .to eq("00-#{faraday_span.hex_trace_id}-#{faraday_span.hex_span_id}-01")
    end

    # Finds the recorded event span for an `appsignal.category` (AS::N name).
    def event_span(category)
      event_spans.find { |span| span.attributes["appsignal.category"] == category }
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
