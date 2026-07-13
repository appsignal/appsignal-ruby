describe Appsignal::Hooks::ShoryukenHook do
  context "with shoryuken" do
    let(:options) { {} }
    before do
      stub_const("Shoryuken", Module.new do
        def self.configure_server
        end

        def self.configure_client
        end
      end)
      configure(:options => options)
      Appsignal::Hooks::ShoryukenHook.new.install
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }

      context "when Shoryuken instrumentation is disabled" do
        let(:options) { { :instrument_shoryuken => false } }

        it { is_expected.to be_falsy }
      end
    end
  end

  context "without shoryuken" do
    before { hide_const "Shoryuken" }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
