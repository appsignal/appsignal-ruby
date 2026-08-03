# frozen_string_literal: true

describe Appsignal::OpenTelemetry::ErrorType do
  describe ".attributes_for" do
    it "uses an exception class name as it is" do
      expect(described_class.attributes_for("RuntimeError")).to eq(
        "error.type" => "RuntimeError"
      )
    end

    it "uses a datastore's error code as it is" do
      expect(described_class.attributes_for("NamespaceNotFound")).to eq(
        "error.type" => "NamespaceNotFound"
      )
    end

    # An anonymous exception class has no name, and a datastore does not always
    # report a code, so there has to be something to fall back to.
    it "reports a failure without a name as _OTHER" do
      expect(described_class.attributes_for(nil)).to eq("error.type" => "_OTHER")
      expect(described_class.attributes_for("")).to eq("error.type" => "_OTHER")
    end

    it "reports an anonymous exception class as _OTHER" do
      error_class = Class.new(StandardError)

      expect(described_class.attributes_for(error_class.name)).to eq(
        "error.type" => "_OTHER"
      )
    end
  end
end
