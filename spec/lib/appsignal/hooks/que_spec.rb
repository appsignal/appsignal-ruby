describe Appsignal::Hooks::QueHook do
  if DependencyHelper.que_present?
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      context "when Que instrumentation is enabled" do
        before { configure }

        it { is_expected.to be_truthy }
      end

      context "when Que instrumentation is disabled" do
        before { configure(:options => { :instrument_que => false }) }

        it { is_expected.to be_falsy }
      end
    end

    it "installs the QuePlugin" do
      expect(Que::Job.included_modules).to include(Appsignal::Integrations::QuePlugin)
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
