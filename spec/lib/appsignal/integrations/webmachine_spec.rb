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
      Webmachine::Request.new(
        "GET",
        "http://google.com:80/foo?param1=value1&param2=value2",
        {},
        nil
      )
    end
    let(:app) do
      proc do
        def to_html
          "Some HTML"
        end
      end
    end
    let(:resource) do
      app_block = app
      Class.new(Webmachine::Resource) do
        class_eval(&app_block) if app_block

        def self.name
          "MyResource"
        end
      end
    end
    let(:resource_instance) { resource.new(request, response) }
    let(:response) { Webmachine::Response.new }
    let(:fsm) { Webmachine::Decision::FSM.new(resource_instance, request, response) }
    before { start_agent }
    around { |example| keep_transactions { example.run } }

    describe "#run" do
      it "creates a transaction" do
        expect { fsm.run }.to(change { created_transactions.count }.by(1))
      end

      it "sets the action" do
        fsm.run
        expect(last_transaction).to have_action("MyResource#GET")
      end

      context "with action already set" do
        let(:app) do
          proc do
            def to_html
              Appsignal.set_action("Custom Action")
              "Some HTML"
            end
          end
        end

        it "doesn't overwrite the action" do
          fsm.run
          expect(last_transaction).to have_action("Custom Action")
        end
      end

      it "records an instrumentation event" do
        fsm.run
        expect(last_transaction).to include_event("name" => "process_action.webmachine")
      end

      it "sets the params" do
        fsm.run
        expect(last_transaction).to include_params("param1" => "value1", "param2" => "value2")
      end

      it "closes the transaction" do
        fsm.run
        expect(last_transaction).to be_completed
        expect(current_transaction?).to be_falsy
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
