require "appsignal/span"

describe Appsignal::Span do
  before { start_agent }

  let(:namespace) { "web" }
  let(:root) { Appsignal::Span.new(namespace) }

  describe "creating a span" do
    it "creates an empty span" do
      expect(root.to_h["namespace"]).to eq "web"
      expect(root.to_h["trace_id"].length).to eq 16
      expect(root.to_h["span_id"].length).to eq 8
      expect(root.to_h["parent_span_id"]).to be_empty
      expect(root.to_h["name"]).to be_empty
      expect(root.to_h["start_time_seconds"]).to be > 1_600_000_000
      expect(root.to_h["start_time_nanoseconds"]).to be_kind_of(Numeric)
      expect(root.to_h["closed"]).to be false
    end
  end

  describe "#child" do
    let(:child) { root.child }

    it "creates a child span" do
      expect(child.to_h["namespace"]).to be_empty
      expect(child.to_h["trace_id"].length).to eq 16
      expect(child.to_h["span_id"].length).to eq 8
      expect(child.to_h["parent_span_id"]).to eq root.to_h["span_id"]
      expect(child.to_h["name"]).to be_empty
      expect(root.to_h["start_time_seconds"]).to be > 1_600_000_000
      expect(root.to_h["start_time_nanoseconds"]).to be_kind_of(Numeric)
      expect(child.to_h["closed"]).to be false
    end
  end

  describe "#add_error" do
    it "adds an error" do
      begin
        raise "Error"
      rescue => error
        root.add_error(error)
      end

      error = root.to_h["error"]
      expect(error["name"]).to eq "RuntimeError"
      expect(error["message"]).to eq "Error"
      expect(error["backtrace_json"]).not_to be_empty
    end
  end

  describe "set_sample_data" do
    it "sets sample data" do
      root.set_sample_data(:params, "key" => "value")

      sample_data = root.to_h["sample_data"]
      expect(sample_data["params"]).to eq "{\"key\":\"value\"}"
    end
  end

  describe "#name=" do
    it "sets the name" do
      root.name = "Span name"

      expect(root.to_h["name"]).to eq "Span name"
    end
  end

  describe "#[]=" do
    let(:attributes) { root.to_h["attributes"] }

    it "sets a string attribute" do
      root["string"] = "attribute"

      expect(attributes["string"]).to eq "attribute"
    end

    it "sets an integer attribute" do
      root["integer"] = 1001

      expect(attributes["integer"]).to eq 1001
    end

    it "sets a bigint attribute" do
      root["bigint"] = 1 << 64

      expect(attributes["bigint"]).to eq "bigint:#{1 << 64}"
    end

    it "sets a boolean attribute" do
      root["true"] = true
      root["false"] = false

      expect(attributes["true"]).to eq true
      expect(attributes["false"]).to eq false
    end

    it "sets a float attribute" do
      root["float"] = 10.01

      expect(attributes["float"]).to eq 10.01
    end

    it "raises an error for other types" do
      expect do
        root["something"] = Object.new
      end.to raise_error TypeError
    end
  end

  describe "#instrument" do
    it "closes the span after yielding" do
      root.instrument do
        # Nothing happening
      end
      expect(root.closed?).to eq true
    end

    context "with an error raised in the passed block" do
      it "closes the span after yielding" do
        expect do
          root.instrument do
            raise ExampleException, "foo"
          end
        end.to raise_error(ExampleException, "foo")
        expect(root.closed?).to eq true
      end
    end
  end

  describe "string encodings" do
    def span_json(span)
      span.instance_variable_get(:@ext).to_json
    end

    shared_examples "a span with valid UTF-8 strings" do |expected|
      it "sends valid UTF-8 in every string field" do
        span = Appsignal::Span.new(string)
        span.name = string
        span[string] = string
        span.set_sample_data(string, string => string)
        span.add_error(StandardError.new(string))

        json = span_json(span)
        expect(json).to be_valid_encoding

        hash = JSON.parse(json)
        expect(hash).to include(
          "namespace" => expected,
          "name" => expected,
          "attributes" => { expected => expected },
          "sample_data" => { expected => %({"#{expected}":"#{expected}"}) }
        )
        expect(hash["error"]).to include("message" => expected)
      end

      it "sends valid UTF-8 for a child span name" do
        child = root.child
        child.name = string

        json = span_json(child)
        expect(json).to be_valid_encoding
        expect(JSON.parse(json)["name"]).to eq(expected)
      end
    end

    context "with invalid bytes in a UTF-8 string" do
      let(:string) { "caf\xE9".dup.force_encoding(Encoding::UTF_8) }

      include_examples "a span with valid UTF-8 strings", "caf\u{FFFD}"
    end

    context "with a binary string of valid UTF-8 bytes" do
      let(:string) { "caf\xC3\xA9".b }

      include_examples "a span with valid UTF-8 strings", "café"
    end

    # The extension reads the bytes as UTF-8 and ignores the Ruby encoding, so
    # the ISO-8859-1 "é" (0xE9) is an invalid byte to it.
    context "with a string in another encoding" do
      let(:string) { "café".encode(Encoding::ISO_8859_1) }

      include_examples "a span with valid UTF-8 strings", "caf\u{FFFD}"
    end
  end

  describe "#close" do
    it "closes a span" do
      expect(root.closed?).to eq false

      root.close

      expect(root.to_h).to be_nil
      expect(root.closed?).to eq true
    end
  end
end
