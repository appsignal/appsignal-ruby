describe Appsignal::Hooks::CelluloidHook do
  context "with celluloid" do
    before :context do
      module Celluloid
        def self.shutdown
          @shut_down = true
        end

        def self.shut_down?
          @shut_down == true
        end
      end
      Appsignal::Hooks::CelluloidHook.new.install
    end
    after :context do
      Object.send(:remove_const, :Celluloid)
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    specify { expect(Appsignal).to receive(:stop) }
    specify { expect(Celluloid.shut_down?).to be true }

    after do
      Celluloid.shutdown
    end
  end

  context "without celluloid" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
