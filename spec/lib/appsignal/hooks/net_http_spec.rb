describe Appsignal::Hooks::NetHttpHook do
  let(:options) { {} }
  before { start_agent(:options => options) }

  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    context "with Net::HTTP instrumentation enabled" do
      it { is_expected.to be_truthy }
    end

    context "with Net::HTTP instrumentation disabled" do
      let(:options) { { :instrument_net_http => false } }

      it { is_expected.to be_falsy }
    end
  end
end
