# frozen_string_literal: true

describe Appsignal::OpenTelemetry::HttpResponse do
  describe ".attributes_for" do
    it "describes the status code" do
      expect(described_class.attributes_for(200)).to eq(
        "http.response.status_code" => 200
      )
    end

    it "describes a status code given as a String" do
      expect(described_class.attributes_for("404")).to eq(
        "http.response.status_code" => 404
      )
    end

    # Callers whose request never produced a response pass the result on without
    # checking.
    it "returns no attributes when there is no status" do
      expect(described_class.attributes_for(nil)).to eq({})
    end

    it "returns no attributes for a status that is not a number" do
      expect(described_class.attributes_for("nonsense")).to eq({})
      expect(described_class.attributes_for("")).to eq({})
    end
  end
end
