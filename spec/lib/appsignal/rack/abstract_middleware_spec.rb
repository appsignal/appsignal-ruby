describe Appsignal::Rack::AbstractMiddleware do
  let(:app) { DummyApp.new }
  let(:env) do
    Rack::MockRequest.env_for(
      "/some/path",
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" => "application/json",
      :params => { "page" => 2, "query" => "lorem" },
      "rack.session" => { "session" => "data", "user_id" => 123 }
    )
  end
  let(:middleware) { described_class.new(app, options) }

  let(:appsignal_env) { :default }
  let(:options) { {} }
  # Pass the example's AppSignal env through to the mode contexts' `start_agent`.
  let(:start_agent_args) { { :env => appsignal_env } }

  def make_request
    middleware.call(env)
  end

  def make_request_with_error(error_class, error_message)
    expect { make_request }.to raise_error(error_class, error_message)
  end

  describe "#call" do
    context "when not active" do
      let(:appsignal_env) { :inactive_env }

      it_in_both_modes "does not instrument the request" do
        expect { make_request }.to_not(change { created_transactions.count })
      end

      it_in_both_modes "calls the next middleware in the stack" do
        make_request
        expect(app).to be_called
      end
    end

    context "when appsignal is active" do
      describe "creates a transaction for the request" do
        def perform
          make_request
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          expect { perform }.to(change { created_transactions.count }.by(1))

          expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          expect { perform }.to(change { created_transactions.count }.by(1))

          expect(root_span.attributes["appsignal.namespace"])
            .to eq(Appsignal::Transaction::HTTP_REQUEST)
          expect(root_span.kind).to eq(:server)
        end
      end

      it_in_both_modes "wraps the response body in a BodyWrapper subclass" do
        _status, _headers, body = make_request
        expect(body).to be_kind_of(Appsignal::Rack::BodyWrapper)
      end

      context "without an error" do
        it_in_both_modes "calls the next middleware in the stack" do
          make_request
          expect(app).to be_called
        end

        describe "does not record an error" do
          def perform
            make_request
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to_not have_error
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(exception_events).to be_empty
          end
        end

        context "without :instrument_event_name option set" do
          let(:options) { {} }

          describe "does not record an instrumentation event" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to_not include_event
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(event_spans).to be_empty
            end
          end
        end

        context "with :instrument_event_name option set" do
          let(:options) { { :instrument_event_name => "event_name.category" } }

          describe "records an instrumentation event" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to include_event(:name => "event_name.category")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(event_spans.map(&:name)).to include("event_name.category")
              span = event_spans.find { |s| s.name == "event_name.category" }
              expect(span).not_to be_nil
              expect(span.parent_span_id).to eq(root_span.span_id)
            end
          end
        end

        # `be_completed` reads `backend._completed?` and `Appsignal::Transaction
        # .current` is the thread-local, so both assertions are backend-agnostic.
        it_in_both_modes "completes the transaction" do
          make_request

          expect(last_transaction).to be_completed
          expect(Appsignal::Transaction.current)
            .to be_kind_of(Appsignal::Transaction::NilTransaction)
        end

        context "when instrument_event_name option is nil" do
          let(:options) { { :instrument_event_name => nil } }

          describe "does not record an instrumentation event" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to_not include_events
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(event_spans).to be_empty
            end
          end
        end
      end

      context "with an error" do
        let(:error) { ExampleException.new("error message") }
        let(:app) { lambda { |_env| raise ExampleException, "error message" } }

        describe "create a transaction for the request" do
          def perform
            make_request_with_error(ExampleException, "error message")
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            expect { perform }.to(change { created_transactions.count }.by(1))

            expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            expect { perform }.to(change { created_transactions.count }.by(1))

            expect(root_span.attributes["appsignal.namespace"])
              .to eq(Appsignal::Transaction::HTTP_REQUEST)
          end
        end

        describe "error" do
          describe "records the error" do
            def perform
              make_request_with_error(ExampleException, "error message")
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to have_error("ExampleException", "error message")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              event = root_span.events.find { |e| e.name == "exception" }
              expect(event).not_to be_nil
              expect(event.attributes["exception.type"]).to eq("ExampleException")
              expect(event.attributes["exception.message"]).to eq("error message")
              expect(event.attributes["exception.stacktrace"]).to be_a(String)
              expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
              expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
            end
          end

          it_in_both_modes "completes the transaction" do
            make_request_with_error(ExampleException, "error message")

            expect(last_transaction).to be_completed
            expect(Appsignal::Transaction.current)
              .to be_kind_of(Appsignal::Transaction::NilTransaction)
          end

          context "with :report_errors set to false" do
            let(:options) { { :report_errors => false } }

            describe "does not record the exception on the transaction" do
              def perform
                make_request_with_error(ExampleException, "error message")
              end

              it "in agent mode", :agent_mode do
                start_agent(**start_agent_args)
                perform

                expect(last_transaction).to_not have_error
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

                expect(exception_events).to be_empty
              end
            end
          end

          context "with :report_errors set to true" do
            let(:options) { { :report_errors => true } }

            describe "records the exception on the transaction" do
              def perform
                make_request_with_error(ExampleException, "error message")
              end

              it "in agent mode", :agent_mode do
                start_agent(**start_agent_args)
                perform

                expect(last_transaction).to have_error("ExampleException", "error message")
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

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

          context "with :report_errors set to a lambda that returns false" do
            let(:options) { { :report_errors => lambda { |_env| false } } }

            describe "does not record the exception on the transaction" do
              def perform
                make_request_with_error(ExampleException, "error message")
              end

              it "in agent mode", :agent_mode do
                start_agent(**start_agent_args)
                perform

                expect(last_transaction).to_not have_error
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

                expect(exception_events).to be_empty
              end
            end
          end

          context "with :report_errors set to a lambda that returns true" do
            let(:options) { { :report_errors => lambda { |_env| true } } }

            describe "records the exception on the transaction" do
              def perform
                make_request_with_error(ExampleException, "error message")
              end

              it "in agent mode", :agent_mode do
                start_agent(**start_agent_args)
                perform

                expect(last_transaction).to have_error("ExampleException", "error message")
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

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

      context "without action name metadata" do
        describe "reports no action name" do
          def perform
            make_request
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to_not have_action
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(root_span.attributes).to_not have_key("appsignal.action_name")
          end
        end
      end

      # Partial duplicate tests from Appsignal::Rack::ApplyRackRequest that
      # ensure the request metadata is set on via the AbstractMiddleware.
      describe "request metadata" do
        describe "sets request metadata" do
          def perform
            env.merge!("PATH_INFO" => "/some/path", "REQUEST_METHOD" => "GET")
            make_request
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to include_metadata(
              "request_method" => "GET",
              "method" => "GET",
              "request_path" => "/some/path",
              "path" => "/some/path"
            )
            expect(last_transaction).to include_environment(
              "REQUEST_METHOD" => "GET",
              "PATH_INFO" => "/some/path"
              # and more, but we don't need to test Rack mock defaults
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            # Metadata is emitted as `appsignal.tag.*` attributes.
            expect(root_span.attributes["appsignal.tag.request_method"]).to eq("GET")
            expect(root_span.attributes["appsignal.tag.method"]).to eq("GET")
            expect(root_span.attributes["appsignal.tag.request_path"]).to eq("/some/path")
            expect(root_span.attributes["appsignal.tag.path"]).to eq("/some/path")
            # Only true HTTP headers map to the `http.request.header.*`
            # convention; the non-header CGI vars (REQUEST_METHOD, PATH_INFO)
            # are intentionally dropped.
            expect(root_span.attributes["http.request.header.accept"]).to eq("application/json")
            expect(root_span.attributes.keys).to_not include("http.request.header.request-method")
          end
        end

        describe "sets request parameters" do
          def perform
            make_request
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to include_params(
              "page" => "2",
              "query" => "lorem"
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            params = JSON.parse(root_span.attributes["appsignal.request.payload"])
            expect(params).to include("page" => "2", "query" => "lorem")
          end
        end

        describe "sets session data" do
          def perform
            make_request
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            perform

            expect(last_transaction).to include_session_data("session" => "data", "user_id" => 123)
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            session = JSON.parse(root_span.attributes["appsignal.request.session_data"])
            expect(session).to include("session" => "data", "user_id" => 123)
          end
        end

        context "with queue start header" do
          let(:queue_start_time) { fixed_time * 1_000 }

          describe "sets the queue start" do
            def perform
              env["HTTP_X_REQUEST_START"] = "t=#{queue_start_time.to_i}" # in milliseconds
              make_request
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to have_queue_start(queue_start_time)
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              # `set_queue_start` is an intentional no-op in collector mode:
              # nothing in the OpenTelemetry pipeline consumes a queue start.
              expect(last_transaction).to_not have_queue_start
            end
          end
        end

        class SomeFilteredRequest
          attr_reader :env

          def initialize(env)
            @env = env
          end

          def path
            "/static/path"
          end

          def request_method
            "GET"
          end

          def filtered_params
            { "abc" => "123" }
          end

          def session
            { "data" => "value" }
          end
        end

        context "with overridden request class and params method" do
          let(:options) do
            { :request_class => SomeFilteredRequest, :params_method => :filtered_params }
          end

          describe "uses the overridden request class and params method to fetch params" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to include_params("abc" => "123")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              params = JSON.parse(root_span.attributes["appsignal.request.payload"])
              expect(params).to include("abc" => "123")
            end
          end

          describe "uses the overridden request class to fetch session data" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to include_session_data("data" => "value")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              session = JSON.parse(root_span.attributes["appsignal.request.session_data"])
              expect(session).to include("data" => "value")
            end
          end
        end
      end

      context "with parent instrumentation" do
        let(:transaction) { http_request_transaction }

        # The parent transaction's backend is mode-specific, so it must be built
        # after the agent starts -- called from each example body, not a `before`.
        def setup_parent_transaction
          env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = transaction
          set_current_transaction(transaction)
        end

        it_in_both_modes "uses the existing transaction" do
          setup_parent_transaction
          make_request

          expect { make_request }.to_not(change { created_transactions.count })
        end

        describe "wraps the response body in a BodyWrapper subclass" do
          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            setup_parent_transaction
            _status, _headers, body = make_request
            expect(body).to be_kind_of(Appsignal::Rack::BodyWrapper)

            body.to_ary
            response_events =
              last_transaction.to_h["events"].count do |event|
                event["name"] == "process_response_body.rack"
              end
            expect(response_events).to eq(1)
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            setup_parent_transaction
            _status, _headers, body = make_request
            expect(body).to be_kind_of(Appsignal::Rack::BodyWrapper)

            body.to_ary
            response_events =
              event_spans.count do |span|
                span.attributes["appsignal.category"] == "process_response_body.rack"
              end
            expect(response_events).to eq(1)
          end
        end

        context "when the response body is already instrumented" do
          let(:body) { Appsignal::Rack::BodyWrapper.wrap(["hello!"], transaction) }
          let(:app) { DummyApp.new { [200, {}, body] } }

          describe "doesn't wrap the body again" do
            def perform
              setup_parent_transaction
              env[Appsignal::Rack::APPSIGNAL_RESPONSE_INSTRUMENTED] = true
              _status, _headers, body = make_request
              expect(body).to eq(body)
              body.to_ary
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              response_events =
                last_transaction.to_h["events"].count do |event|
                  event["name"] == "process_response_body.rack"
                end
              expect(response_events).to eq(1)
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              response_events =
                event_spans.count do |span|
                  span.attributes["appsignal.category"] == "process_response_body.rack"
                end
              expect(response_events).to eq(1)
            end
          end
        end

        context "with error" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }

          describe "doesn't record the error on the transaction" do
            def perform
              setup_parent_transaction
              make_request_with_error(ExampleException, "error message")
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to_not have_error
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform
              # The middleware leaves the parent open; finish it so its span
              # exports and we can confirm no exception event was recorded.
              Appsignal::Transaction.complete_current!

              expect(exception_events).to be_empty
            end
          end
        end

        it_in_both_modes "doesn't complete the existing transaction" do
          setup_parent_transaction
          make_request

          expect(env[Appsignal::Rack::APPSIGNAL_TRANSACTION]).to_not be_completed
        end

        context "with custom set action name" do
          describe "does not overwrite the action name" do
            def perform
              setup_parent_transaction
              env[Appsignal::Rack::APPSIGNAL_TRANSACTION].set_action("My custom action")
              env["appsignal.action"] = "POST /my-action"
              make_request
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to have_action("My custom action")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform
              Appsignal::Transaction.complete_current!

              expect(root_span.name).to eq("My custom action")
              expect(root_span.attributes["appsignal.action_name"]).to eq("My custom action")
            end
          end
        end

        context "with :report_errors set to false" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }
          let(:options) { { :report_errors => false } }

          describe "does not record the error on the transaction" do
            def perform
              setup_parent_transaction
              make_request_with_error(ExampleException, "error message")
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to_not have_error
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform
              Appsignal::Transaction.complete_current!

              expect(exception_events).to be_empty
            end
          end
        end

        context "with :report_errors set to true" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }
          let(:options) { { :report_errors => true } }

          describe "records the error on the transaction" do
            def perform
              setup_parent_transaction
              make_request_with_error(ExampleException, "error message")
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to have_error("ExampleException", "error message")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform
              Appsignal::Transaction.complete_current!

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

        context "with :report_errors set to a lambda that returns false" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }
          let(:options) { { :report_errors => lambda { |_env| false } } }

          describe "does not record the exception on the transaction" do
            def perform
              setup_parent_transaction
              make_request_with_error(ExampleException, "error message")
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to_not have_error
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform
              Appsignal::Transaction.complete_current!

              expect(exception_events).to be_empty
            end
          end
        end

        context "with :report_errors set to a lambda that returns true" do
          let(:app) { lambda { |_env| raise ExampleException, "error message" } }
          let(:options) { { :report_errors => lambda { |_env| true } } }

          describe "records the error on the transaction" do
            def perform
              setup_parent_transaction
              make_request_with_error(ExampleException, "error message")
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)
              perform

              expect(last_transaction).to have_error("ExampleException", "error message")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform
              Appsignal::Transaction.complete_current!

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
  end
end
