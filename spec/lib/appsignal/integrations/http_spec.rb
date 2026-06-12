# frozen_string_literal: true

if DependencyHelper.http_present?
  require "appsignal/integrations/http"

  describe Appsignal::Integrations::HttpIntegration do
    let(:transaction) { http_request_transaction }

    describe "instrumenting a HTTP request" do
      def perform
        stub_request(:get, "http://www.google.com")

        HTTP.get("http://www.google.com")
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform

        expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        expect(transaction).to include_event(
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "name" => "request.http_rb",
          "title" => "GET http://www.google.com"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(root_span.attributes["appsignal.namespace"])
          .to eq(Appsignal::Transaction::HTTP_REQUEST)
        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("GET http://www.google.com")
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
        expect(span.attributes).not_to have_key("appsignal.body")
      end
    end

    describe "instrumenting a HTTPS request" do
      def perform
        stub_request(:get, "https://www.google.com")

        HTTP.get("https://www.google.com")
      end

      it "in agent mode", :agent_mode do
        start_agent
        set_current_transaction(transaction)
        perform

        expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        expect(transaction).to include_event(
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "name" => "request.http_rb",
          "title" => "GET https://www.google.com"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        expect(root_span.attributes["appsignal.namespace"])
          .to eq(Appsignal::Transaction::HTTP_REQUEST)
        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("GET https://www.google.com")
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
        expect(span.attributes).not_to have_key("appsignal.body")
      end
    end

    context "with request parameters" do
      describe "not including the query parameters in the title" do
        def perform
          stub_request(:get, "https://www.google.com?q=Appsignal")

          HTTP.get("https://www.google.com", :params => { :q => "Appsignal" })
        end

        it "in agent mode", :agent_mode do
          start_agent
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "body" => "",
            "title" => "GET https://www.google.com"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("GET https://www.google.com")
          expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
          expect(span.attributes).not_to have_key("appsignal.body")
        end
      end

      describe "not including the request body in the title" do
        def perform
          stub_request(:post, "https://www.google.com")
            .with(:body => { :q => "Appsignal" }.to_json)

          HTTP.post("https://www.google.com", :json => { :q => "Appsignal" })
        end

        it "in agent mode", :agent_mode do
          start_agent
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "body" => "",
            "title" => "POST https://www.google.com"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("POST https://www.google.com")
          expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
          expect(span.attributes).not_to have_key("appsignal.body")
        end
      end
    end

    describe "following redirects" do
      # `HTTP.follow` chains through `HTTP::Session#request` in http6, which is
      # instrumented separately from `HTTP::Client#request`. The event is
      # recorded at the request boundary, so a redirected request is a single
      # `request.http_rb` event spanning every hop.
      it "records a single event spanning every hop" do
        stub_request(:get, "http://www.google.com")
          .to_return(:status => 301, :headers => { "Location" => "http://www.example.com" })
        stub_request(:get, "http://www.example.com").to_return(:status => 200)

        HTTP.follow.get("http://www.google.com")

        events = transaction.to_h["events"]
          .select { |event| event["name"] == "request.http_rb" }
        expect(events.map { |event| event["title"] }).to eq(
          ["GET http://www.google.com"]
        )
      end
    end

    context "with various URI objects" do
      describe "parsing an object responding to #to_s" do
        def perform
          request_uri = Struct.new(:uri) do
            def to_s
              uri.to_s
            end
          end

          stub_request(:get, "http://www.google.com")

          HTTP.get(request_uri.new("http://www.google.com"))
        end

        it "in agent mode", :agent_mode do
          start_agent
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "name" => "request.http_rb",
            "title" => "GET http://www.google.com"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("GET http://www.google.com")
          expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
        end
      end

      describe "parsing an URI object" do
        def perform
          stub_request(:get, "http://www.google.com")

          HTTP.get(URI("http://www.google.com"))
        end

        it "in agent mode", :agent_mode do
          start_agent
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "name" => "request.http_rb",
            "title" => "GET http://www.google.com"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("GET http://www.google.com")
          expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
        end
      end

      describe "parsing an HTTP::URI object" do
        def perform
          stub_request(:get, "http://www.google.com")

          HTTP.get(HTTP::URI.parse("http://www.google.com"))
        end

        it "in agent mode", :agent_mode do
          start_agent
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "name" => "request.http_rb",
            "title" => "GET http://www.google.com"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("GET http://www.google.com")
          expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
        end
      end

      describe "parsing a string" do
        def perform
          stub_request(:get, "http://www.google.com")

          HTTP.get("http://www.google.com")
        end

        it "in agent mode", :agent_mode do
          start_agent
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "name" => "request.http_rb",
            "title" => "GET http://www.google.com"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("GET http://www.google.com")
          expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
        end
      end

      describe "parsing a string with non-ascii characters" do
        def perform
          stub_request(:get, "http://www.example.com/áéíóúãÔù")

          HTTP.get("http://www.example.com/áéíóúãÔù")
        end

        it "in agent mode", :agent_mode do
          start_agent
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "name" => "request.http_rb",
            "title" => "GET http://www.example.com"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("GET http://www.example.com")
          expect(span.attributes["appsignal.category"]).to eq("request.http_rb")
        end
      end
    end
  end
end
