describe Appsignal::Hooks::NetHttpHook do
  before(:context) { start_agent }

  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    context "with Net::HTTP instrumentation enabled" do
      it { is_expected.to be_truthy }
    end

    context "with Net::HTTP instrumentation disabled" do
      before { Appsignal.config.config_hash[:instrument_net_http] = false }
      after { Appsignal.config.config_hash[:instrument_net_http] = true }

      it { is_expected.to be_falsy }
    end
  end
end
