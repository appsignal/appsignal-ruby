describe Appsignal::Hooks::ResqueHook do
  describe "#dependency_present?" do
    subject { described_class.new.dependencies_present? }

    context "when Resque is loaded" do
      before { stub_const "Resque", 1 }

      it { is_expected.to be_truthy }
    end

    context "when Resque is not loaded" do
      before { hide_const "Resque" }

      it { is_expected.to be_falsy }
    end
  end

  if DependencyHelper.resque_present?
    describe "#install" do
      before { start_agent }

      it "adds the ResqueIntegration module to Resque::Job" do
        expect(Resque::Job.included_modules).to include(Appsignal::Integrations::ResqueIntegration)
      end
    end
  end
end
