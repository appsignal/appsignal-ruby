# frozen_string_literal: true

describe Appsignal::OpenTelemetry::HttpClientRequest do
  describe ".attributes_for" do
    def attributes_for(**args)
      described_class.attributes_for(**args)
    end

    it "describes the method, the host and port, and the URL" do
      expect(
        attributes_for(
          :method => "GET",
          :scheme => "https",
          :host => "example.com",
          :port => 443,
          :path => "/users/1"
        )
      ).to eq(
        "http.request.method" => "GET",
        "server.address" => "example.com",
        "server.port" => 443,
        "url.full" => "https://example.com/users/1"
      )
    end

    # A URL is normally written without the port its scheme implies, but the
    # conventions ask for the port either way.
    it "leaves a scheme's own port out of the URL" do
      expect(
        attributes_for(:method => "GET", :scheme => "http", :host => "example.com", :port => 80)
      ).to include(
        "server.port" => 80,
        "url.full" => "http://example.com/"
      )
    end

    it "keeps a port the scheme does not imply in the URL" do
      expect(
        attributes_for(
          :method => "GET", :scheme => "http", :host => "example.com", :port => 8080,
          :path => "/path"
        )
      ).to include(
        "server.port" => 8080,
        "url.full" => "http://example.com:8080/path"
      )
    end

    # Some clients only name a port when the URL did, so the scheme's own port
    # has to stand in. The conventions ask for the port on every client span.
    it "falls back to the scheme's own port" do
      expect(
        attributes_for(:method => "GET", :scheme => "https", :host => "example.com")
      ).to include(
        "server.port" => 443,
        "url.full" => "https://example.com/"
      )
    end

    it "accepts a port given as a String" do
      expect(
        attributes_for(:method => "GET", :scheme => "http", :host => "example.com", :port => "8080")
      ).to include("server.port" => 8080)
    end

    # Some clients hand us a request target rather than a path, which can carry
    # the query string along with it.
    it "cuts the query string off the path" do
      expect(
        attributes_for(
          :method => "GET", :scheme => "https", :host => "example.com",
          :path => "/search?q=secret"
        )
      ).to include("url.full" => "https://example.com/search")
    end

    # A URL can carry a username and password, which must not be sent. Building
    # the URL from the parts means there is nowhere for them to come from.
    it "cannot include credentials" do
      expect(
        attributes_for(
          :method => "GET", :scheme => "https", :host => "example.com", :path => "/path"
        )["url.full"]
      ).to eq("https://example.com/path")
    end

    it "leaves out the URL when there is no host to build it from" do
      attributes = attributes_for(:method => "GET", :scheme => "https")

      expect(attributes).to_not have_key("url.full")
      expect(attributes).to_not have_key("server.address")
      expect(attributes["http.request.method"]).to eq("GET")
    end

    it "leaves out the URL when there is no scheme to build it from" do
      attributes = attributes_for(:method => "GET", :host => "example.com")

      expect(attributes).to_not have_key("url.full")
      expect(attributes).to_not have_key("server.port")
      expect(attributes["server.address"]).to eq("example.com")
    end

    it "normalizes the request method" do
      expect(
        attributes_for(:method => :get, :scheme => "https", :host => "example.com")
      ).to include(
        "http.request.method" => "GET",
        "http.request.method_original" => "get"
      )
    end

    # Some clients report the path of a request to the root of a host as empty,
    # and others as "/". The request goes to "/" either way.
    it "describes a request without a path as one to the root" do
      expect(
        attributes_for(:method => "GET", :scheme => "https", :host => "example.com", :path => "")
      ).to include("url.full" => "https://example.com/")
    end

    it "returns no attributes when there is nothing to describe" do
      expect(attributes_for(:method => nil)).to eq({})
    end
  end
end
