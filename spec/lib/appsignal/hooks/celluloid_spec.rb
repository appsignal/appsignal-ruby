describe Appsignal::Hooks::CelluloidHook do
  context "with celluloid" do
    before do
      stub_const("Celluloid", Module.new do
        def self.shutdown
          @shut_down = true
        end

        def self.shut_down?
          @shut_down == true
        end
      end)
      Appsignal::Hooks::CelluloidHook.new.install
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    describe "#install" do
      it "calls Appsignal.stop on shutdown" do
        expect(Appsignal).to receive(:stop)
        Celluloid.shutdown
        expect(Celluloid.shut_down?).to be true
      end
    end
  end

  context "without celluloid" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
