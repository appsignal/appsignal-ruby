if DependencyHelper.webmachine_present?
  require "appsignal/integrations/webmachine"

  class Response
    attr_accessor :code

    def body
      ""
    end

    def headers
      {}
    end
  end

  describe Appsignal::Integrations::WebmachineIntegration do
    let(:request) do
      Webmachine::Request.new("GET", "http://google.com:80/foo", {}, nil)
    end
    let(:resource)    { double(:trace? => false, :handle_exception => true, :"code=" => nil) }
    let(:response)    { Response.new }
    let(:transaction) { double(:set_action_if_nil => true) }
    let(:fsm) { Webmachine::Decision::FSM.new(resource, request, response) }
    before(:context) { start_agent }

    # Make sure the request responds to the method we need to get query params.
    describe "request" do
      it "should respond to `query`" do
        expect(request).to respond_to(:query)
      end
    end

    describe "#run" do
      before do
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
        expect(fsm).to receive(:run)
      end

      it "should instrument the original method" do
        expect(Appsignal).to receive(:instrument).with("process_action.webmachine")
      end

      it "should close the transaction" do
        expect(Appsignal::Transaction).to receive(:complete_current!)
      end

      after { fsm.run }

      describe "concerning the response" do
        it "sets a response code" do
          expect(fsm.response.code).to be_nil
          fsm.run
          expect(fsm.response.code).not_to be_nil
        end
      end
    end

    describe "#handle_exceptions" do
      let(:error) { ExampleException }

      it "should catch the error and send it to AppSignal" do
        expect(Appsignal).to receive(:set_error).with(error)
      end

      after do
        fsm.send(:handle_exceptions) { raise error }
      end
    end
  end
end
