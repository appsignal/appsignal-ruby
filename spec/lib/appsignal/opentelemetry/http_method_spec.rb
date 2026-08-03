# frozen_string_literal: true

describe Appsignal::OpenTelemetry::HttpMethod do
  describe ".attributes_for" do
    it "passes a known method through, with nothing to preserve" do
      expect(described_class.attributes_for("GET")).to eq(
        "http.request.method" => "GET"
      )
    end

    it "recognizes every method the semantic conventions define" do
      %w[CONNECT DELETE GET HEAD OPTIONS PATCH POST PUT TRACE].each do |method|
        expect(described_class.attributes_for(method)).to eq(
          "http.request.method" => method
        )
      end
    end

    # Method names are case sensitive, so a lowercase method is not the known
    # method. It is replaced by the canonical form, keeping what we were given.
    it "upcases a known method given in another case, keeping the original" do
      expect(described_class.attributes_for("get")).to eq(
        "http.request.method" => "GET",
        "http.request.method_original" => "get"
      )
    end

    it "accepts a Symbol, as the HTTP client integrations pass" do
      expect(described_class.attributes_for(:post)).to eq(
        "http.request.method" => "POST",
        "http.request.method_original" => "post"
      )
    end

    # The conventions treat the method as a closed set, so anything outside it
    # has to be reported as `_OTHER` rather than passed through.
    it "reports an unknown method as _OTHER, keeping the original" do
      expect(described_class.attributes_for("PROPFIND")).to eq(
        "http.request.method" => "_OTHER",
        "http.request.method_original" => "PROPFIND"
      )
    end

    it "keeps the original of an unknown method exactly as given" do
      expect(described_class.attributes_for("PropFind")).to eq(
        "http.request.method" => "_OTHER",
        "http.request.method_original" => "PropFind"
      )
    end

    # Callers that could not read a method pass the result on without checking,
    # and an empty Hash adds no attributes.
    it "returns no attributes when there is no method" do
      expect(described_class.attributes_for(nil)).to eq({})
      expect(described_class.attributes_for("")).to eq({})
    end
  end
end
