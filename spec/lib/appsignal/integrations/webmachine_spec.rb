if DependencyHelper.webmachine_present?
  require "appsignal/integrations/webmachine"

  describe Appsignal::Integrations::WebmachinePlugin::FSM do
    let(:request) do
      Webmachine::Request.new("GET", "http://google.com:80/foo", {}, nil)
    end
    let(:resource)    { double(:trace? => false, :handle_exception => true) }
    let(:response)    { double }
    let(:transaction) { double(:set_action_if_nil => true) }
    let(:fsm) { Webmachine::Decision::FSM.new(resource, request, response) }
    before(:context) { start_agent }

    # Make sure the request responds to the method we need to get query params.
    describe "request" do
      it "should respond to `query`" do
        expect(request).to respond_to(:query)
      end
    end

    describe "#run_with_appsignal" do
      before do
        allow(fsm).to receive(:request).and_return(request)
        allow(fsm).to receive(:run_without_appsignal).and_return(true)
        allow(SecureRandom).to receive(:uuid).and_return("uuid")
        allow(Appsignal::Transaction).to receive(:create).and_return(transaction)
      end

      it "should create a transaction" do
        expect(Appsignal::Transaction).to receive(:create).with(
          "uuid",
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          :params_method => :query
        ).and_return(transaction)
      end

      it "should set the action" do
        expect(transaction).to receive(:set_action_if_nil).with("RSpec::Mocks::Double#GET")
      end

      it "should call the original method" do
        expect(fsm).to receive(:run_without_appsignal)
      end

      it "should instrument the original method" do
        expect(Appsignal).to receive(:instrument).with("process_action.webmachine")
      end

      it "should close the transaction" do
        expect(Appsignal::Transaction).to receive(:complete_current!)
      end

      after { fsm.run }
    end

    describe "#handle_exceptions_with_appsignal" do
      let(:error) { ExampleStandardError.new }

      it "should catch the error and send it to AppSignal" do
        expect(Appsignal).to receive(:set_error).with(error)
      end

      after do
        fsm.send(:handle_exceptions) { raise error }
      end
    end
  end
end
