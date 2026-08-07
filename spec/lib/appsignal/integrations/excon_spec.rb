if DependencyHelper.excon_present?
  require "excon"
  require "appsignal/integrations/excon"

  # Integration test against the real Excon gem. The hook instruments the
  # connection, so a request is one event that covers the whole of it: sending
  # the request, waiting for the remote service, and reading the response.
  describe "Excon integration" do
    before { Appsignal::Hooks::ExconHook.new.install }

    let(:transaction) { http_request_transaction }
    before do
      start_agent
      set_current_transaction(transaction)
    end

    def event_names
      transaction.to_h["events"].map { |event| event["name"] }
    end

    def event_duration(name)
      transaction.to_h["events"].find { |event| event["name"] == name }["duration"]
    end

    describe "a request that succeeds" do
      def perform
        stub_request(:get, "http://www.example.com/")
        Excon.get("http://www.example.com/")
      end

      it "records the request as one event" do
        perform

        expect(event_names).to eq(["request.excon"])
        expect(transaction).to include_event(
          "name" => "request.excon",
          "title" => "GET http://www.example.com",
          "body" => ""
        )
      end

      it "returns the response to the caller" do
        expect(perform.status).to eq(200)
      end
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

      it "is recorded on the event" do
        perform

        expect(event_duration("request.excon")).to be >= 100
      end
    end

    describe "a request that fails" do
      def perform
        stub_request(:get, "http://www.example.com/").to_timeout
        expect { Excon.get("http://www.example.com/") }
          .to raise_error(Excon::Error::Timeout)
      end

      it "records the request as one event, and lets the error through" do
        perform

        expect(event_names).to eq(["request.excon"])
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

      it "records no event, and still returns the response" do
        expect(perform.status).to eq(200)

        expect(event_names).to be_empty
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

      it "records every attempt as one event" do
        perform

        expect(event_names).to eq(["request.excon"])
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

      it "records every hop as one event" do
        perform

        expect(event_names).to eq(["request.excon"])
        # The event is titled after the request that was made, not the location
        # it ended up at.
        expect(transaction).to include_event(
          "name" => "request.excon",
          "title" => "GET http://www.example.com"
        )
      end
    end
  end
end
