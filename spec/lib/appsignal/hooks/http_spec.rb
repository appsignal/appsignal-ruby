describe Appsignal::Hooks::HttpHook do
  before :context do
    start_agent
  end

  context "with HTTP instrumentation enabled" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "should instrument a http request" do
      Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
      expect(Appsignal::Transaction.current).to receive(:start_event)
        .at_least(:once)
      expect(Appsignal::Transaction.current).to receive(:finish_event)
        .at_least(:once)
        .with("request.http_rb", "GET http://www.google.com", nil, 0)

      stub_request(:any, "http://www.google.com/")

      HTTP.get("http://www.google.com")
    end

    it "should instrument a https request" do
      Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
      expect(Appsignal::Transaction.current).to receive(:start_event)
        .at_least(:once)
      expect(Appsignal::Transaction.current).to receive(:finish_event)
        .at_least(:once)
        .with("request.http_rb", "GET https://www.google.com", nil, 0)

      stub_request(:any, "https://www.google.com/")

      HTTP.get("https://www.google.com")
    end
  end

  context "with HTTP instrumentation disabled" do
    before { Appsignal.config.config_hash[:instrument_http_rb] = false }
    after { Appsignal.config.config_hash[:instrument_http_rb] = true }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
