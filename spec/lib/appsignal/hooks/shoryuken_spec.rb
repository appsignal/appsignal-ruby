describe Appsignal::Hooks::ShoryukenHook do
  context "with shoryuken" do
    before do
      stub_const("Shoryuken", Module.new do
        def self.configure_server
        end

        def self.configure_client
        end
      end)
      Appsignal::Hooks::ShoryukenHook.new.install
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
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
