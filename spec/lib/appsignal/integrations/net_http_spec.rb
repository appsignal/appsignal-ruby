require "appsignal/integrations/net_http"

describe Appsignal::Integrations::NetHttpIntegration do
  describe "a http request" do
    def perform
      stub_request(:any, "http://www.google.com/")

      Net::HTTP.get_response(URI.parse("http://www.google.com"))
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      perform

      expect(transaction).to include_event(
        "name" => "request.net_http",
        "title" => "GET http://www.google.com",
        "body" => ""
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      perform
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_spans.first
      expect(span.name).to eq("GET http://www.google.com")
      expect(span.kind).to eq(:client)
      expect(span.parent_span_id).to eq(root_span.span_id)
      expect(span.attributes["appsignal.category"]).to eq("request.net_http")
      expect(span.attributes).not_to have_key("appsignal.body")

      # The outgoing request carries a W3C traceparent for the client span, so
      # the called service joins this trace.
      expect(injected_traceparent("http://www.google.com/"))
        .to eq("00-#{span.hex_trace_id}-#{span.hex_span_id}-01")
    end
  end

  describe "a https request" do
    def perform
      stub_request(:any, "https://www.google.com/")

      uri = URI.parse("https://www.google.com")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get(uri.request_uri)
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      perform

      expect(transaction).to include_event(
        "name" => "request.net_http",
        "title" => "GET https://www.google.com",
        "body" => ""
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      perform
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_spans.first
      expect(span.name).to eq("GET https://www.google.com")
      expect(span.kind).to eq(:client)
      expect(span.parent_span_id).to eq(root_span.span_id)
      expect(span.attributes["appsignal.category"]).to eq("request.net_http")
      expect(span.attributes).not_to have_key("appsignal.body")

      expect(injected_traceparent("https://www.google.com/"))
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
