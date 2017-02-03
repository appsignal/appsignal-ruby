describe Appsignal::System do
  describe ".container?" do
    subject { described_class.container? }

    context "when on Heroku" do
      around { |example| recognize_as_heroku { example.run } }

      it "returns true" do
        is_expected.to eq(true)
      end
    end

    context "when in docker" do
      around { |example| recognize_as_container(:docker) { example.run } }

      it "returns true" do
        is_expected.to be_truthy
      end
    end

    context "when not in container" do
      around { |example| recognize_as_container(:none) { example.run } }

      it "returns false" do
        is_expected.to be_falsy
      end
    end
  end

  describe ".heroku?" do
    subject { described_class.heroku? }

    context "when on Heroku" do
      around { |example| recognize_as_heroku { example.run } }

      it "returns true" do
        is_expected.to eq(true)
      end
    end

    context "when not on Heroku" do
      around { |example| recognize_as_container(:none) { example.run } }

      it "returns false" do
        is_expected.to eq(false)
      end
    end
  end
end
