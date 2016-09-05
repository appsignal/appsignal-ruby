if webmachine_present?
  describe Appsignal::Hooks::WebmachineHook do
    context "with webmachine" do
      before(:all) do
        Appsignal::Hooks::WebmachineHook.new.install
      end

      its(:dependencies_present?) { should be_true }

      let(:fsm) { Webmachine::Decision::FSM.new(double(:trace? => false), double, double) }

      it "should include the run alias methods" do
        expect( fsm ).to respond_to(:run_with_appsignal)
        expect( fsm ).to respond_to(:run_without_appsignal)
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
