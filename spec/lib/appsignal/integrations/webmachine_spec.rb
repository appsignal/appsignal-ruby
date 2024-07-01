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
    let(:resource) { double(:trace? => false, :handle_exception => true, :"code=" => nil) }
    let(:response) { Response.new }
    let(:fsm) { Webmachine::Decision::FSM.new(resource, request, response) }
    before(:context) { start_agent }
    around { |example| keep_transactions { example.run } }

    # Make sure the request responds to the method we need to get query params.
    describe "request" do
      it "responds to #query" do
        expect(request).to respond_to(:query)
      end
    end

    describe "#run" do
      before { allow(fsm).to receive(:call).and_call_original }

      it "creates a transaction" do
        expect { fsm.run }.to(change { created_transactions.count }.by(1))
      end

      it "sets the action" do
        fsm.run
        expect(last_transaction).to have_action("RSpec::Mocks::Double#GET")
      end

      it "records an instrumentation event" do
        fsm.run
        expect(last_transaction).to include_event("name" => "process_action.webmachine")
      end

      it "closes the transaction" do
        fsm.run
        expect(last_transaction).to be_completed
        expect(current_transaction?).to be_falsy
      end

      it "sets a response code" do
        expect(fsm.response.code).to be_nil
        fsm.run
        expect(fsm.response.code).not_to be_nil
      end
    end

    describe "#handle_exceptions" do
      let(:error) { ExampleException.new("error message") }
      let(:transaction) { http_request_transaction }

      it "tracks the error" do
        with_current_transaction(transaction) do
          fsm.send(:handle_exceptions) { raise error }
        end

        expect(last_transaction).to have_error("ExampleException", "error message")
      end
    end
  end
end
