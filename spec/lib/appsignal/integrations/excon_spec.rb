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
        expect(excon_span.kind).to eq(:client)
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
        expect(excon_span.name).to eq("request.excon (GET http://www.example.com)")
      end
    end
  end
end
