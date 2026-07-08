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
        {
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/some/path",
          "HTTP_ACCEPT" => "application/json",
          "ignored_header" => "something"
        },
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

    describe "#run" do
      def perform
        fsm.run
      end

      it_in_both_modes "creates a transaction" do
        expect { perform }.to(change { created_transactions.count }.by(1))
      end

      describe "sets the action" do
        it "in agent mode", :agent_mode do
          start_agent
          perform
          expect(last_transaction).to have_action("MyResource#GET")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          expect(root_span.name).to eq("MyResource#GET")
          expect(root_span.kind).to eq(:server)
          expect(root_span.attributes["appsignal.action_name"]).to eq("MyResource#GET")
        end
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

        describe "doesn't overwrite the action" do
          it "in agent mode", :agent_mode do
            start_agent
            perform
            expect(last_transaction).to have_action("Custom Action")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform
            expect(root_span.name).to eq("Custom Action")
            expect(root_span.attributes["appsignal.action_name"]).to eq("Custom Action")
          end
        end
      end

      describe "records an instrumentation event" do
        it "in agent mode", :agent_mode do
          start_agent
          perform
          expect(last_transaction).to include_event("name" => "process_action.webmachine")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          span = event_spans.find { |s| s.name == "process_action.webmachine" }
          expect(span).not_to be_nil
          expect(span.parent_span_id).to eq(root_span.span_id)
        end
      end

      describe "sets the params" do
        it "in agent mode", :agent_mode do
          start_agent
          perform
          expect(last_transaction).to include_params("param1" => "value1", "param2" => "value2")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          params = JSON.parse(root_span.attributes["appsignal.request.payload"])
          expect(params).to include("param1" => "value1", "param2" => "value2")
        end
      end

      describe "sets the headers" do
        it "in agent mode", :agent_mode do
          start_agent
          perform
          expect(last_transaction).to include_environment(
            "REQUEST_METHOD" => "GET",
            "PATH_INFO" => "/some/path",
            "HTTP_ACCEPT" => "application/json"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          # Only true HTTP headers map to `http.request.header.*`; the non-header
          # CGI vars (REQUEST_METHOD, PATH_INFO) are intentionally dropped.
          expect(root_span.attributes["http.request.header.accept"]).to eq("application/json")
          expect(root_span.attributes.keys).to_not include("http.request.header.request-method")
        end
      end

      it_in_both_modes "closes the transaction" do
        perform
        expect(last_transaction).to be_completed
        expect(current_transaction?).to be_falsy
      end

      context "with parent transaction" do
        let(:transaction) { http_request_transaction }
        # The parent is set inside each example rather than in a `before`: in
        # collector mode the transaction must be created after the example body
        # has enabled collector mode (via `start_collector_agent`), so it gets
        # the OpenTelemetry backend.

        describe "sets the action" do
          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform
            expect(last_transaction).to have_action("MyResource#GET")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            # The parent transaction is not closed by `fsm.run`; finish it so
            # its span is exported.
            transaction.complete
            expect(root_span.name).to eq("MyResource#GET")
            expect(root_span.attributes["appsignal.action_name"]).to eq("MyResource#GET")
          end
        end

        describe "sets the params" do
          it "in agent mode", :agent_mode do
            start_agent
            set_current_transaction(transaction)
            perform
            last_transaction._sample
            expect(last_transaction).to include_params("param1" => "value1", "param2" => "value2")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            set_current_transaction(transaction)
            perform
            # The parent transaction is not closed by `fsm.run`; finish it so
            # its span is exported.
            transaction.complete
            params = JSON.parse(root_span.attributes["appsignal.request.payload"])
            expect(params).to include("param1" => "value1", "param2" => "value2")
          end
        end

        it_in_both_modes "does not close the transaction" do
          set_current_transaction(transaction)
          expect(last_transaction).to_not be_completed
        end
      end
    end

    describe "#handle_exceptions" do
      let(:error) { ExampleException.new("error message") }
      let(:transaction) { http_request_transaction }

      describe "tracks the error" do
        it "in agent mode", :agent_mode do
          start_agent
          with_current_transaction(transaction) do
            fsm.send(:handle_exceptions) { raise error }
          end

          expect(last_transaction).to have_error("ExampleException", "error message")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          with_current_transaction(transaction) do
            fsm.send(:handle_exceptions) { raise error }
          end
          # Not completed by `handle_exceptions`; finish it to export the span.
          transaction.complete

          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.type"]).to eq("ExampleException")
          expect(event.attributes["exception.message"]).to eq("error message")
          expect(event.attributes["exception.stacktrace"]).to be_a(String)
          expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
          expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        end
      end
    end
  end
end
