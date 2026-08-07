if DependencyHelper.faraday_present?
  require "faraday"
  require "appsignal/integrations/faraday"

  # Integration test against the real Faraday gem. The hook auto-installs
  # AppSignal's middleware onto every connection, so the `request.faraday` event
  # is recorded and outgoing requests carry trace context, without the user
  # adding anything -- and without a dependency on ActiveSupport (these gemfiles
  # no longer load it).
  describe "Faraday integration" do
    before { Appsignal::Hooks::FaradayHook.new.install }

    describe "claiming the request.faraday event" do
      # The event formatter registry is shared by the whole test suite, so put
      # back whatever this example changes.
      around do |example|
        formatters = Appsignal::EventFormatter.formatters.dup
        formatter_classes = Appsignal::EventFormatter.formatter_classes.dup
        example.run
      ensure
        Appsignal::EventFormatter.formatters.replace(formatters)
        Appsignal::EventFormatter.formatter_classes.replace(formatter_classes)
      end

      # This integration records the request itself, so Faraday's own
      # notification must not record it a second time. Installing is what
      # claims it, and this hook only installs when Faraday instrumentation is
      # enabled. With it disabled nothing records the request twice, so the
      # notification is left to be recorded like any other.
      it "is claimed on install" do
        Appsignal::EventFormatter.unregister(
          "request.faraday",
          Appsignal::EventFormatter::RecordedElsewhere
        )
        expect(Appsignal::EventFormatter.record?("request.faraday")).to be(true)

        Appsignal::Hooks::FaradayHook.new.install

        expect(Appsignal::EventFormatter.record?("request.faraday")).to be(false)
      end
    end

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
        expect(faraday_span.attributes["http.request.method"]).to eq("GET")
        # The client hands us the method as a lowercase Symbol, so the
        # canonical form is recorded and the original kept alongside it.
        expect(faraday_span.attributes["http.request.method_original"]).to eq("get")
        expect(faraday_span.attributes["server.address"]).to eq("www.example.com")
        expect(faraday_span.attributes["server.port"]).to eq(80)
        expect(faraday_span.attributes["url.full"]).to eq("http://www.example.com/")
        expect(faraday_span.attributes["http.response.status_code"]).to eq(200)
        expect(faraday_span.parent_span_id).to eq(root_span.span_id)
        expect(scope_of(faraday_span)).to eq(["appsignal-ruby/faraday", Appsignal::VERSION])

        # Net::HTTP is suppressed, so there's no nested net_http span.
        expect(event_span("request.net_http")).to be_nil

        # Faraday writes the wire traceparent (Net::HTTP doesn't run its inject).
        expect(injected_traceparent("http://www.example.com/"))
          .to eq("00-#{faraday_span.hex_trace_id}-#{faraday_span.hex_span_id}-01")
      end
    end

    # Excon is the other adapter AppSignal instruments itself, so it is the other
    # adapter that has to be suppressed. Net::HTTP above suppresses through its
    # own integration; Excon suppresses through a different one, so both are
    # worth a test.
    describe "a request over the Excon adapter", :if => DependencyHelper.excon_present? do
      before { Appsignal::Hooks::ExconHook.new.install }

      def perform
        stub_request(:get, "http://www.example.com/")
        connection = Faraday.new("http://www.example.com") do |faraday|
          faraday.adapter :excon
        end
        connection.get("/")
      end

      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform

        expect(transaction).to include_event(
          "name" => "request.faraday",
          "title" => "GET http://www.example.com",
          "body" => ""
        )
        # Excon is suppressed under Faraday, so it isn't recorded again.
        expect(transaction).to_not include_event("name" => "request.excon")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        # Excon is suppressed, so there's no nested excon span.
        expect(event_span("request.excon")).to be_nil

        # Faraday writes the wire traceparent. Excon's own inject middleware
        # still runs, but with no Excon event span of its own it can only write
        # the same client span Faraday already wrote.
        faraday_span = event_span("request.faraday")
        expect(faraday_span).not_to be_nil
        expect(injected_traceparent("http://www.example.com/"))
          .to eq("00-#{faraday_span.hex_trace_id}-#{faraday_span.hex_span_id}-01")
      end
    end

    # With an adapter AppSignal does not instrument at all (here Faraday's test
    # adapter), our inject middleware is the only thing writing context, so the
    # request carries the `request.faraday` client span's traceparent -- proving
    # the middleware runs and injects inside that event's span. This is the path
    # that gives Faraday propagation for adapters AppSignal doesn't instrument
    # directly.
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

    # Finds the recorded event span for a category (AS::N name), which now leads
    # the event span's name.
    def event_span(category)
      event_span_for(category)
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
