describe Appsignal::System do
  describe ".heroku?" do
    subject { described_class.heroku? }

    context "when on Heroku" do
      around { |example| recognize_as_heroku { example.run } }

      it "returns true" do
        is_expected.to eq(true)
      end
    end

    context "when not on Heroku" do
      it "returns false" do
        is_expected.to eq(false)
      end
    end
  end
end
