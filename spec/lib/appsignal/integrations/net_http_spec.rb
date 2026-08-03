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
      expect(span.name).to eq("request.net_http (GET http://www.google.com)")
      expect(span.kind).to eq(:client)
      expect(span.attributes["http.request.method"]).to eq("GET")
      expect(span.attributes["server.address"]).to eq("www.google.com")
      expect(span.attributes["server.port"]).to eq(80)
      expect(span.attributes["url.full"]).to eq("http://www.google.com/")
      expect(span.attributes["http.response.status_code"]).to eq(200)
      expect(span.parent_span_id).to eq(root_span.span_id)
      expect(event_category(span)).to eq("request.net_http")
      expect(scope_of(span)).to eq(["appsignal-ruby/net_http", Appsignal::VERSION])
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
      expect(span.name).to eq("request.net_http (GET https://www.google.com)")
      expect(span.kind).to eq(:client)
      expect(span.attributes["http.request.method"]).to eq("GET")
      expect(span.attributes["server.address"]).to eq("www.google.com")
      expect(span.attributes["server.port"]).to eq(443)
      expect(span.attributes["url.full"]).to eq("https://www.google.com/")
      expect(span.attributes["http.response.status_code"]).to eq(200)
      expect(span.parent_span_id).to eq(root_span.span_id)
      expect(event_category(span)).to eq("request.net_http")
      expect(scope_of(span)).to eq(["appsignal-ruby/net_http", Appsignal::VERSION])
      expect(span.attributes).not_to have_key("appsignal.body")

      expect(injected_traceparent("https://www.google.com/"))
        .to eq("00-#{span.hex_trace_id}-#{span.hex_span_id}-01")
    end
  end

  describe "a request with a path and a query string" do
    def perform
      stub_request(:any, "http://www.google.com/search?q=secret")

      Net::HTTP.get_response(URI.parse("http://www.google.com/search?q=secret"))
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

      span = event_spans.first
      # The client gives us a request target, which carries the query string.
      # The URL keeps the path and drops the query string.
      expect(span.attributes["url.full"]).to eq("http://www.google.com/search")
    end
  end

  describe "a request the server answered with an error" do
    def perform
      stub_request(:any, "http://www.google.com/").to_return(:status => 503)

      Net::HTTP.get_response(URI.parse("http://www.google.com"))
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      perform

      expect(transaction).to include_event(
        "name" => "request.net_http",
        "title" => "GET http://www.google.com"
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      perform
      Appsignal::Transaction.complete_current!

      # A response the server answered with an error is still a response, so it
      # is reported the same way a successful one is.
      expect(event_spans.first.attributes["http.response.status_code"]).to eq(503)
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
