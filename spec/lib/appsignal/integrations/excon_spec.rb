if DependencyHelper.excon_present?
  require "excon"
  require "appsignal/integrations/excon"

  # Integration test against the real Excon gem. The hook instruments the
  # connection, so a request is one event that covers the whole of it: sending
  # the request, waiting for the remote service, and reading the response.
  describe "Excon integration" do
    before { Appsignal::Hooks::ExconHook.new.install }

    let(:transaction) { http_request_transaction }

    def event_names
      transaction.to_h["events"].map { |event| event["name"] }
    end

    def event_duration(name)
      transaction.to_h["events"].find { |event| event["name"] == name }["duration"]
    end

    # The single span an Excon request records.
    def excon_span
      event_span_for("request.excon")
    end

    # How long a span lasted, in milliseconds. Spans carry nanoseconds.
    def span_duration(span)
      (span.end_timestamp - span.start_timestamp) / 1_000_000.0
    end

    # Reads the `traceparent` header off the last recorded outgoing request to
    # `url`. Returns nil when nothing wrote one.
    def injected_traceparent(url)
      traceparent = nil
      # The block is a predicate, so it has to match whatever it reads. It is
      # only here to get at the headers of the requests that were made.
      matcher = a_request(:get, url).with do |request|
        traceparent = request.headers["Traceparent"]
        true
      end
      expect(matcher).to have_been_made.at_least_once
      traceparent
    end

    # The W3C traceparent that names `span` as the parent, sampled.
    def traceparent_for(span)
      "00-#{span.hex_trace_id}-#{span.hex_span_id}-01"
    end

    describe "a request that succeeds" do
      def perform
        stub_request(:get, "http://www.example.com/")
        Excon.get("http://www.example.com/")
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform

        expect(event_names).to eq(["request.excon"])
        expect(transaction).to include_event(
          "name" => "request.excon",
          "title" => "GET http://www.example.com",
          "body" => ""
        )
        # Trace context is only written in collector mode.
        expect(injected_traceparent("http://www.example.com/")).to be_nil
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = excon_span
        expect(span.name).to eq("request.excon (GET http://www.example.com)")
        expect(span.kind).to eq(:client)
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(scope_of(span)).to eq(["appsignal-ruby/excon", Appsignal::VERSION])

        # The request and the response are described on the same span. Excon's
        # own instrumentor could only report the status on a span of its own,
        # which carried nothing else.
        expect(span.attributes["http.request.method"]).to eq("GET")
        # Excon hands us the method as a lowercase Symbol, so the canonical form
        # is recorded and the original kept alongside it.
        expect(span.attributes["http.request.method_original"]).to eq("get")
        expect(span.attributes["server.address"]).to eq("www.example.com")
        expect(span.attributes["server.port"]).to eq(80)
        expect(span.attributes["url.full"]).to eq("http://www.example.com/")
        expect(span.attributes["http.response.status_code"]).to eq(200)

        # The called service joins this trace, as a child of the client span.
        expect(injected_traceparent("http://www.example.com/"))
          .to eq(traceparent_for(span))
      end
    end

    it_in_both_modes "returns the response to the caller" do
      set_current_transaction(transaction)
      stub_request(:get, "http://www.example.com/")

      expect(Excon.get("http://www.example.com/").status).to eq(200)
    end

    # Excon runs its middleware stack twice for a request: once on the way out to
    # send it, and again on the way back to read the response. Instrumenting the
    # connection puts both passes inside the event, so the wait for the remote
    # service is measured.
    describe "the time spent reading the response" do
      # Stands in for Excon's own ResponseParser middleware. It spends time in
      # the response pass, in the same place Excon really blocks.
      let(:slow_response_middleware) do
        Class.new(Excon::Middleware::Base) do
          def response_call(datum)
            sleep 0.1
            @stack.response_call(datum)
          end
        end
      end

      def perform
        stub_request(:get, "http://www.example.com/")
        Excon.get(
          "http://www.example.com/",
          :middlewares => [slow_response_middleware] + Excon.defaults[:middlewares]
        )
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform

        expect(event_duration("request.excon")).to be >= 100
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(span_duration(excon_span)).to be >= 100
      end
    end

    describe "a request that fails" do
      def perform
        stub_request(:get, "http://www.example.com/").to_timeout
        expect { Excon.get("http://www.example.com/") }
          .to raise_error(Excon::Error::Timeout)
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform

        expect(event_names).to eq(["request.excon"])
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = excon_span
        expect(span.kind).to eq(:client)
        # Says what kind of failure ended the request, which the conventions ask
        # for on a span whose operation failed. Recorded because the whole
        # request now runs inside one instrumented block, which sets this when
        # the block raises.
        expect(span.attributes["error.type"]).to eq("Excon::Error::Timeout")
        # No response was received, so there is no status to describe.
        expect(span.attributes).to_not have_key("http.response.status_code")
      end
    end

    # An outer HTTP client integration, such as Faraday, records a request
    # itself and asks the client it runs on not to record it again.
    describe "a request made while HTTP client events are suppressed" do
      def perform
        stub_request(:get, "http://www.example.com/")
        Appsignal::Transaction.current.suppress_http_client_events do
          Excon.get("http://www.example.com/")
        end
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)

        expect(perform.status).to eq(200)
        expect(event_names).to be_empty
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)

        expect(perform.status).to eq(200)
        Appsignal::Transaction.complete_current!

        expect(event_spans).to be_empty
      end
    end

    # Excon retries a request when it is marked idempotent and fails with a
    # socket error. It retries by asking the connection to make the request
    # again, from inside the request it is retrying, so the retries are part of
    # the same event.
    describe "a request that is retried" do
      def perform
        stub_request(:get, "http://www.example.com/").to_timeout
        expect do
          Excon.get(
            "http://www.example.com/",
            :idempotent => true,
            :retry_limit => 3
          )
        end.to raise_error(Excon::Error::Timeout)
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform

        expect(event_names).to eq(["request.excon"])
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        # Every attempt shares the one span, so every attempt carries the same
        # trace context.
        expect(injected_traceparent("http://www.example.com/"))
          .to eq(traceparent_for(excon_span))
      end
    end

    # Excon follows a redirect the same way, by making the request again from
    # inside the request being redirected, so every hop is part of the same
    # event.
    describe "a request that is redirected" do
      def perform
        stub_request(:get, "http://www.example.com/").to_return(
          :status => 302,
          :headers => { "Location" => "http://www.example.com/next" }
        )
        stub_request(:get, "http://www.example.com/next")
        Excon.get(
          "http://www.example.com/",
          :middlewares =>
            [Excon::Middleware::RedirectFollower] + Excon.defaults[:middlewares]
        )
      end

      # The event is named after the request that was made, not the location it
      # ended up at.
      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform

        expect(event_names).to eq(["request.excon"])
        expect(transaction).to include_event(
          "name" => "request.excon",
          "title" => "GET http://www.example.com"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = excon_span
        expect(span.name).to eq("request.excon (GET http://www.example.com)")
        # The span describes the request that was made and the response that
        # came back, so the URL is the one asked for and the status is the one
        # the last hop answered with.
        expect(span.attributes["url.full"]).to eq("http://www.example.com/")
        expect(span.attributes["http.response.status_code"]).to eq(200)
      end
    end

    # A pipelined request is the one case where the event does not cover a whole
    # request. Excon returns from the call once the request has been sent, and
    # the response is read later, so there is no response to describe. It hands
    # back the request data rather than a response.
    describe "a pipelined request" do
      def perform
        stub_request(:get, "http://www.example.com/")
        Excon.new("http://www.example.com/")
          .request(:method => :get, :pipeline => true)
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)

        expect(perform).to be_kind_of(Hash)
        expect(event_names).to eq(["request.excon"])
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = excon_span
        expect(span.attributes["url.full"]).to eq("http://www.example.com/")
        expect(span.attributes).to_not have_key("http.response.status_code")
      end
    end
  end
end
