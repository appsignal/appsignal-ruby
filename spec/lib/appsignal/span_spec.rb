require "appsignal/span"

describe Appsignal::Span do
  before :context do
    start_agent
  end

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

  describe "#close" do
    it "closes a span" do
      expect(root.closed?).to eq false

      root.close

      expect(root.to_h).to be_nil
      expect(root.closed?).to eq true
    end
  end
end
