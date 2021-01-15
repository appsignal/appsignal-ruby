describe Appsignal::Hooks::WebmachineHook do
  if DependencyHelper.webmachine_present?
    context "with webmachine" do
      let(:fsm) { Webmachine::Decision::FSM.new(double(:trace? => false), double, double) }
      before(:context) { start_agent }

      describe "#dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it { is_expected.to be_truthy }
      end

      it "adds behavior to Webmachine::Decision::FSM" do
        expect(fsm.class.ancestors.first).to eq(Appsignal::Integrations::WebmachineIntegration)
      end
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
