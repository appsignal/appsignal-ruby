# frozen_string_literal: true

describe Appsignal::OpenTelemetry::HttpServerRequest do
  describe ".attributes_for" do
    it "describes the method, path, scheme and query string" do
      expect(
        described_class.attributes_for(
          :method => "GET",
          :path => "/users/1",
          :scheme => "https",
          :query => "page=2&query=lorem"
        )
      ).to eq(
        "http.request.method" => "GET",
        "url.path" => "/users/1",
        "url.scheme" => "https",
        "url.query" => "page=2&query=lorem"
      )
    end

    # A request without a query string gets no query attribute, rather than an
    # empty one. Rack reports a missing query string as an empty String.
    it "leaves out an empty query string" do
      expect(
        described_class.attributes_for(:method => "GET", :path => "/", :query => "")
      ).to eq(
        "http.request.method" => "GET",
        "url.path" => "/"
      )
    end

    it "describes the host, the port and the protocol version" do
      expect(
        described_class.attributes_for(
          :method => "GET",
          :path => "/",
          :host => "example.com",
          :port => 443,
          :protocol => "HTTP/1.1"
        )
      ).to eq(
        "http.request.method" => "GET",
        "url.path" => "/",
        "server.address" => "example.com",
        "server.port" => 443,
        "network.protocol.version" => "1.1"
      )
    end

    # Rack reads the port out of the request authority, so it can arrive as the
    # String it was written as. The conventions ask for a number.
    it "reports the port as a number" do
      expect(
        described_class.attributes_for(:method => "GET", :host => "example.com", :port => "8080")
      ).to include("server.port" => 8080)
    end

    # The conventions ask for the port only alongside the host, because a port
    # on its own describes nothing.
    it "leaves out the port when there is no host" do
      expect(described_class.attributes_for(:method => "GET", :port => 443)).to eq(
        "http.request.method" => "GET"
      )
    end

    # A protocol that is not HTTP needs `network.protocol.name` to go with the
    # version, so a value we cannot name is left out altogether.
    it "leaves out a protocol it cannot name" do
      expect(described_class.attributes_for(:method => "GET", :protocol => "SPDY")).to eq(
        "http.request.method" => "GET"
      )
    end

    # The method goes through the same normalization as anywhere else, so an
    # unknown method is reported as `_OTHER` with the original kept.
    it "normalizes the request method" do
      expect(
        described_class.attributes_for(:method => "get", :path => "/", :scheme => "http")
      ).to eq(
        "http.request.method" => "GET",
        "http.request.method_original" => "get",
        "url.path" => "/",
        "url.scheme" => "http"
      )
    end

    # Reading any of these from the request can fail, and the callers pass on
    # whatever they got without checking.
    it "leaves out a value it was not given" do
      expect(described_class.attributes_for(:method => "GET")).to eq(
        "http.request.method" => "GET"
      )
    end

    it "leaves out an empty value" do
      expect(
        described_class.attributes_for(
          :method => "GET", :path => "", :scheme => "", :query => ""
        )
      ).to eq("http.request.method" => "GET")
    end

    it "returns no attributes when there is nothing to describe" do
      expect(described_class.attributes_for(:method => nil)).to eq({})
    end
  end
end
