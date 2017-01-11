describe Appsignal::Hooks::WebmachineHook do
  if DependencyHelper.webmachine_present?
    context "with webmachine" do
      let(:fsm) { Webmachine::Decision::FSM.new(double(:trace? => false), double, double) }
      before(:all) { start_agent }

      its(:dependencies_present?) { should be_true }

      it "should include the run alias methods" do
        expect(fsm).to respond_to(:run_with_appsignal)
        expect(fsm).to respond_to(:run_without_appsignal)
      end

      it "should include the handle_exceptions alias methods" do
        expect(
          fsm.respond_to?(:handle_exceptions_with_appsignal, true)
        ).to be_true

        expect(
          fsm.respond_to?(:handle_exceptions_without_appsignal, true)
        ).to be_true
      end
    end
  end
end
