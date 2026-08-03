if DependencyHelper.excon_present?
  require "excon"
  require "appsignal/integrations/excon"

  # Integration test against the real Excon gem. The hook registers AppSignal as
  # Excon's instrumentor, and Excon calls an instrumentor three times per
  # request: once when it sends the request, once when it reads the response, and
  # once when the request fails. AppSignal turns each of those calls into its own
  # event.
  #
  # These examples record what that produces today, including the parts of it
  # that are wrong.
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

      it "records the request and the response as two separate events" do
        perform

        expect(event_names).to eq(["request.excon", "response.excon"])
      end

      it "titles the request event after the request" do
        perform

        expect(transaction).to include_event(
          "name" => "request.excon",
          "title" => "GET http://www.example.com",
          "body" => ""
        )
      end

      # Excon gives an instrumentor only the response when it reads one, and the
      # response holds no host, so the title this event is built from is never
      # there. It has been titleless since the integration was written.
      it "leaves the response event without a title" do
        perform

        expect(transaction).to include_event(
          "name" => "response.excon",
          "title" => "",
          "body" => ""
        )
      end
    end

    # Excon runs its middleware stack twice for a request: once on the way out to
    # send it, and again on the way back to read the response. Those are two
    # separate passes, and the middleware that reads the response off the socket
    # runs outside the one that calls the instrumentor.
    #
    # So the time spent waiting for the remote service lands on neither event. An
    # Excon request is reported as taking almost no time, however slow it was.
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

      it "is recorded on neither event" do
        perform

        expect(event_duration("request.excon")).to be < 50
        expect(event_duration("response.excon")).to be < 50
      end
    end

    describe "a request that fails" do
      def perform
        stub_request(:get, "http://www.example.com/").to_timeout
        expect { Excon.get("http://www.example.com/") }
          .to raise_error(Excon::Error::Timeout)
      end

      it "records the request and the failure as two separate events" do
        perform

        expect(event_names).to eq(["request.excon", "error.excon"])
      end

      # Excon gives an instrumentor only the error when a request fails. The
      # title is built from a request that is not there, so every failed request
      # is titled with the leftover punctuation of that format.
      it "titles the failure event with an empty request" do
        perform

        expect(transaction).to include_event(
          "name" => "error.excon",
          "title" => " ://",
          "body" => ""
        )
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
    # again, so each attempt is instrumented on its own.
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

      it "records an event per attempt, and one for the failure" do
        perform

        expect(event_names).to eq(
          ["request.excon", "retry.excon", "retry.excon", "error.excon"]
        )
      end
    end

    # Excon follows a redirect by making the request again against the new
    # location, so each hop is instrumented on its own. The hop that redirects
    # never reaches the instrumentor with its response, because the middleware
    # that follows the redirect replaces it, so only the last hop records one.
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

      it "records an event per hop, and one response for the last hop" do
        perform

        expect(event_names).to eq(
          ["request.excon", "request.excon", "response.excon"]
        )
      end
    end
  end
end
