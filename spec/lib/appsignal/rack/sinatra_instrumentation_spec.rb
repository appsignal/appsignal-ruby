if DependencyHelper.sinatra_present?
  require "appsignal/rack/sinatra_instrumentation"

  module SinatraRequestHelpers
    def make_request
      middleware.call(env)
    end

    def make_request_with_error(error)
      expect { middleware.call(env) }.to raise_error(error)
    end
  end

  describe Appsignal::Rack::SinatraInstrumentation do
    include SinatraRequestHelpers

    let(:settings) { double(:raise_errors => false) }
    let(:app) { double(:call => true, :settings => settings) }
    let(:env) do
      Rack::MockRequest.env_for("/path", "sinatra.route" => "GET /path", "REQUEST_METHOD" => "GET")
    end
    let(:middleware) { Appsignal::Rack::SinatraInstrumentation.new(app) }

    describe "#call" do
      before { allow(middleware).to receive(:raw_payload).and_return({}) }

      it_in_both_modes "doesn't instrument requests" do
        expect { make_request }.to_not(change { created_transactions.count })
      end
    end

    describe ".settings" do
      it_in_both_modes "returns the app's settings" do
        expect(middleware.settings).to eq(app.settings)
      end
    end
  end

  describe Appsignal::Rack::SinatraBaseInstrumentation do
    include SinatraRequestHelpers

    let(:settings) { double(:raise_errors => false) }
    let(:app) { double(:call => true, :settings => settings) }
    let(:env) do
      Rack::MockRequest.env_for("/path", "sinatra.route" => "GET /path", "REQUEST_METHOD" => "GET")
    end
    let(:appsignal_env) { :default }
    let(:options) { {} }
    let(:middleware) { Appsignal::Rack::SinatraBaseInstrumentation.new(app, options) }

    # Pass the example's Appsignal env through to the mode contexts' `start_agent`.
    let(:start_agent_args) { { :env => appsignal_env } }

    describe "#initialize" do
      context "with no settings method in the Sinatra app" do
        let(:app) { double(:call => true) }

        it_in_both_modes "does not raise errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with no raise_errors setting in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double) }

        it_in_both_modes "does not raise errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with raise_errors turned off in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double(:raise_errors => false)) }

        it_in_both_modes "raises errors" do
          expect(middleware.raise_errors_on).to be(false)
        end
      end

      context "with raise_errors turned on in the Sinatra app" do
        let(:app) { double(:call => true, :settings => double(:raise_errors => true)) }

        it_in_both_modes "raises errors" do
          expect(middleware.raise_errors_on).to be(true)
        end
      end
    end

    describe "#call" do
      before { allow(middleware).to receive(:raw_payload).and_return({}) }

      context "when appsignal is not active" do
        let(:appsignal_env) { :inactive_env }

        it_in_both_modes "does not instrument requests" do
          expect { make_request }.to_not(change { created_transactions.count })
        end

        it_in_both_modes "calls the next middleware in the stack" do
          make_request

          expect(app).to have_received(:call).with(env)
        end
      end

      context "when appsignal is active" do
        context "without an error" do
          describe "creates a transaction for the request" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              expect { perform }.to(change { created_transactions.count }.by(1))

              expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
            end

            it "in collector mode", :collector_mode do
              expect { perform }.to(change { created_transactions.count }.by(1))

              expect(root_span.attributes["appsignal.namespace"])
                .to eq("web")
              expect(root_span.kind).to eq(:server)
            end
          end

          describe "reports a process_action.sinatra event" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              perform

              expect(last_transaction).to include_event("name" => "process_action.sinatra")
            end

            it "in collector mode", :collector_mode do
              perform

              span = event_spans.find { |s| s.name == "process_action.sinatra" }
              expect(span).not_to be_nil
              expect(span.parent_span_id).to eq(root_span.span_id)
            end
          end
        end

        context "with an error in sinatra.error" do
          let(:error) { ExampleException.new("error message") }
          before { env["sinatra.error"] = error }

          describe "creates a transaction for the request" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              expect { perform }.to(change { created_transactions.count }.by(1))

              expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
            end

            it "in collector mode", :collector_mode do
              expect { perform }.to(change { created_transactions.count }.by(1))

              expect(root_span.attributes["appsignal.namespace"])
                .to eq("web")
            end
          end

          context "when raise_errors is off" do
            let(:settings) { double(:raise_errors => false) }

            describe "records the error" do
              def perform
                make_request
              end

              it "in agent mode", :agent_mode do
                perform

                expect(last_transaction).to have_error("ExampleException", "error message")
              end

              it "in collector mode", :collector_mode do
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

          context "when raise_errors is on" do
            let(:settings) { double(:raise_errors => true) }

            describe "does not record the error" do
              def perform
                make_request
              end

              it "in agent mode", :agent_mode do
                perform

                expect(last_transaction).to_not have_error
              end

              it "in collector mode", :collector_mode do
                perform

                expect(exception_events).to be_empty
              end
            end
          end

          context "if sinatra.skip_appsignal_error is set" do
            before do
              env.merge!(
                "sinatra.error" => error,
                "sinatra.skip_appsignal_error" => true
              )
            end

            describe "does not record the error" do
              def perform
                make_request
              end

              it "in agent mode", :agent_mode do
                perform

                expect(last_transaction).to_not have_error
              end

              it "in collector mode", :collector_mode do
                perform

                expect(exception_events).to be_empty
              end
            end
          end
        end

        describe "action name" do
          describe "sets the action to the request method and path" do
            def perform
              make_request
            end

            it "in agent mode", :agent_mode do
              perform

              expect(last_transaction).to have_action("GET /path")
            end

            it "in collector mode", :collector_mode do
              perform

              expect(root_span.name).to eq("GET /path")
              expect(root_span.attributes["appsignal.action_name"]).to eq("GET /path")
            end
          end

          context "without 'sinatra.route' env" do
            let(:env) do
              Rack::MockRequest.env_for("/path", "REQUEST_METHOD" => "GET")
            end

            describe "doesn't set an action name" do
              def perform
                make_request
              end

              it "in agent mode", :agent_mode do
                perform

                expect(last_transaction).to_not have_action
              end

              it "in collector mode", :collector_mode do
                perform

                expect(root_span.attributes).to_not have_key("appsignal.action_name")
              end
            end
          end

          context "with mounted modular application" do
            before { env["SCRIPT_NAME"] = "/api" }

            describe "sets the action name with an application prefix path" do
              def perform
                make_request
              end

              it "in agent mode", :agent_mode do
                perform

                expect(last_transaction).to have_action("GET /api/path")
              end

              it "in collector mode", :collector_mode do
                perform

                expect(root_span.name).to eq("GET /api/path")
                expect(root_span.attributes["appsignal.action_name"]).to eq("GET /api/path")
              end
            end

            context "without 'sinatra.route' env" do
              let(:env) do
                Rack::MockRequest.env_for("/path", "REQUEST_METHOD" => "GET")
              end

              describe "doesn't set an action name" do
                def perform
                  make_request
                end

                it "in agent mode", :agent_mode do
                  perform

                  expect(last_transaction).to_not have_action
                end

                it "in collector mode", :collector_mode do
                  perform

                  expect(root_span.attributes).to_not have_key("appsignal.action_name")
                end
              end
            end
          end
        end
      end
    end
  end
end
