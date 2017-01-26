describe Appsignal::Hooks::PassengerHook do
  context "with passenger" do
    before(:context) do
      module PhusionPassenger
      end
    end
    after(:context) { Object.send(:remove_const, :PhusionPassenger) }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "adds behavior to stopping_worker_process and starting_worker_process" do
      expect(PhusionPassenger).to receive(:on_event).with(:starting_worker_process)
      expect(PhusionPassenger).to receive(:on_event).with(:stopping_worker_process)

      Appsignal::Hooks::PassengerHook.new.install
    end
  end

  context "without passenger" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
