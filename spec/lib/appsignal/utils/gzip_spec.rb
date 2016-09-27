describe Appsignal::Utils::Gzip do
  describe ".compress" do
    let(:value) { "foo" }
    subject { described_class.compress(value).force_encoding("UTF-8") }

    it "returns a gziped value" do
      expect(subject).to eq("x\u0001K\xCB\xCF\a\u0000\u0002\x82\u0001E")
    end
  end
end
