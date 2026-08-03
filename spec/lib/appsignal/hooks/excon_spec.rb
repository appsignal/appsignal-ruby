describe Appsignal::Hooks::ExconHook do
  let(:options) { {} }
  before { start_agent(:options => options) }

  context "with Excon" do
    before do
      stub_const("Excon", Module.new)
      stub_const("Excon::Connection", Class.new)
      Appsignal::Hooks::ExconHook.new.install
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }

      context "when Excon instrumentation is disabled" do
        let(:options) { { :instrument_excon => false } }

        it { is_expected.to be_falsy }
      end
    end

    describe "#install" do
      it "adds the AppSignal integration to Excon connections" do
        expect(Excon::Connection.ancestors)
          .to include(Appsignal::Integrations::ExconIntegration)
      end
    end
  end

  context "without Excon" do
    before { hide_const "Excon" }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
