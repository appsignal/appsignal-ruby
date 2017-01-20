describe Appsignal::Hooks::CelluloidHook do
  context "with celluloid" do
    before :all do
      module Celluloid
        def self.shutdown
        end
      end
      Appsignal::Hooks::CelluloidHook.new.install
    end
    after :all do
      Object.send(:remove_const, :Celluloid)
    end

    describe '#dependencies_present?' do
      subject { super().dependencies_present? }
      it { is_expected.to be_truthy }
    end

    specify { expect(Appsignal).to receive(:stop) }
    specify { expect(Celluloid).to receive(:shutdown_without_appsignal) }

    after do
      Celluloid.shutdown
    end
  end

  context "without celluloid" do
    describe '#dependencies_present?' do
      subject { super().dependencies_present? }
      it { is_expected.to be_falsy }
    end
  end
end
