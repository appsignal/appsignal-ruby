describe Appsignal::AuthCheck do
  let(:config) { project_fixture_config }
  let(:logger) { Logger.new(StringIO.new) }
  let(:auth_check) { Appsignal::AuthCheck.new(config, logger) }

  describe "#perform_with_result" do
    it "should give success message" do
      expect(auth_check).to receive(:perform).and_return("200")
      expect(auth_check.perform_with_result).to eq ["200", "AppSignal has confirmed authorization!"]
    end

    it "should give 401 message" do
      expect(auth_check).to receive(:perform).and_return("401")
      expect(auth_check.perform_with_result).to eq ["401", "API key not valid with AppSignal..."]
    end

    it "should give an error message" do
      expect(auth_check).to receive(:perform).and_return("402")
      expect(auth_check.perform_with_result).to eq ["402", "Could not confirm authorization: 402"]
    end
  end

  context "transmitting" do
    before do
      @transmitter = double
      expect(Appsignal::Transmitter).to receive(:new).with(
        "auth",
        kind_of(Appsignal::Config)
      ).and_return(@transmitter)
    end

    describe "#perform" do
      it "should not transmit any extra data" do
        expect(@transmitter).to receive(:transmit).with({}).and_return({})
        auth_check.perform
      end
    end
  end
end
