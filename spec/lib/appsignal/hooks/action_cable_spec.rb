# frozen_string_literal: true

describe Appsignal::Hooks::ActionCableHook do
  if DependencyHelper.action_cable_present?
    context "with ActionCable" do
      require "action_cable/engine"
      # Require test helper to test with ConnectionStub
      require "action_cable/channel/test_case" if DependencyHelper.rails6_present?

      describe ".dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it "returns true" do
          is_expected.to be_truthy
        end
      end

      describe ActionCable::Channel::Base do
        let(:channel) do
          Class.new(ActionCable::Channel::Base) do
            def speak(_data)
            end

            def self.to_s
              "MyChannel"
            end
          end
        end
        let(:log) { StringIO.new }
        let(:server) do
          ActionCable::Server::Base.new.tap do |s|
            s.config.logger = ActiveSupport::Logger.new(log)
          end
        end
        let(:env) do
          http_request_env_with_data(
            "action_dispatch.request_id" => request_id,
            :params => params,
            :with_queue_start => true
          )
        end
        let(:request) do
          ActionDispatch::Request.new(env).tap do |req|
            set_rails_session_data(
              req,
              "user_id" => "123",
              "session" => "yes"
            )
          end
        end
        let(:connection) { ActionCable::Connection::Base.new(server, request.env) }
        let(:identifier) { { :channel => "MyChannel" }.to_json }
        let(:params) { {} }
        let(:request_id) { SecureRandom.uuid }
        let(:instance) { channel.new(connection, identifier, params) }
        before do
          # Stub transmit call for subscribe/unsubscribe tests
          allow(connection).to receive(:websocket)
            .and_return(instance_double("ActionCable::Connection::WebSocket", :transmit => nil))
        end
        around { |example| keep_transactions { example.run } }

        describe "#perform_action" do
          describe "creates a transaction for an action" do
            def perform
              instance.perform_action("message" => "foo", "action" => "speak")
            end

            it "in agent mode", :agent_mode do
              start_agent
              perform

              transaction = last_transaction
              expect(transaction).to have_id
              expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
              expect(transaction).to have_action("MyChannel#speak")
              expect(transaction).to_not have_error
              expect(transaction).to include_metadata(
                "method" => "websocket",
                "path" => "/blog"
              )
              expect(transaction).to include_event(
                "body" => "",
                "body_format" => Appsignal::EventFormatter::DEFAULT,
                "count" => 1,
                "name" => "perform_action.action_cable",
                "title" => ""
              )
              expect(transaction).to include_params(
                "action" => "speak",
                "message" => "foo"
              )
              expect(transaction).to include_session_data(
                "user_id" => "123",
                "session" => "yes"
              )
              expect(transaction).to include_tags("request_id" => request_id)
              expect(transaction).to_not have_queue_start
              expect(transaction).to be_completed
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(root_span.kind).to eq(:server)
              expect(root_span.name).to eq("MyChannel#speak")
              expect(root_span.attributes["appsignal.namespace"])
                .to eq(Appsignal::Transaction::ACTION_CABLE)
              expect(root_span.attributes["appsignal.action_name"]).to eq("MyChannel#speak")
              expect(exception_events).to be_empty
              expect(root_span.attributes["appsignal.tag.method"]).to eq("websocket")
              expect(root_span.attributes["appsignal.tag.path"]).to eq("/blog")
              span = event_spans.find { |s| s.name == "perform_action.action_cable" }
              expect(span).not_to be_nil
              expect(span.parent_span_id).to eq(root_span.span_id)
              expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
                .to eq("action" => "speak", "message" => "foo")
              expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
                .to eq("user_id" => "123", "session" => "yes")
              expect(root_span.attributes["appsignal.tag.request_id"]).to eq(request_id)
              expect(root_span.attributes).not_to have_key("queue_start")
              expect(last_transaction).to be_completed
            end
          end

          context "without request_id (standalone server)" do
            let(:request_id) { nil }

            describe "sets a generated request ID" do
              def perform
                # Subscribe action sets the request_id in the env
                instance.subscribe_to_channel
                instance.perform_action("message" => "foo", "action" => "speak")
              end

              it "in agent mode", :agent_mode do
                start_agent
                perform
                expect(last_transaction).to include_tags("request_id" => kind_of(String))
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

                # Two server spans: one for subscribe, one for perform_action.
                # The last one is the perform_action span.
                perform_span = span_exporter.finished_spans
                  .select { |s| [:server, :consumer].include?(s.kind) }
                  .last
                expect(perform_span.attributes["appsignal.tag.request_id"])
                  .to be_a(String)
              end
            end
          end

          context "with an error in the action" do
            let(:channel) do
              Class.new(ActionCable::Channel::Base) do
                def speak(_data)
                  raise ExampleException, "oh no!"
                end

                def self.to_s
                  "MyChannel"
                end
              end
            end

            describe "registers an error on the transaction" do
              def perform
                expect do
                  instance.perform_action("message" => "foo", "action" => "speak")
                end.to raise_error(ExampleException)
              end

              it "in agent mode", :agent_mode do
                start_agent
                perform

                transaction = last_transaction
                expect(transaction).to have_id
                expect(transaction).to have_action("MyChannel#speak")
                expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
                expect(transaction).to have_error("ExampleException", "oh no!")
                expect(transaction).to include_metadata(
                  "method" => "websocket",
                  "path" => "/blog"
                )
                expect(transaction).to include_params(
                  "action" => "speak",
                  "message" => "foo"
                )
                expect(transaction).to_not have_queue_start
                expect(transaction).to be_completed
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

                expect(root_span.attributes["appsignal.action_name"]).to eq("MyChannel#speak")
                expect(root_span.attributes["appsignal.namespace"])
                  .to eq(Appsignal::Transaction::ACTION_CABLE)
                event = root_span.events.find { |e| e.name == "exception" }
                expect(event).not_to be_nil
                expect(event.attributes["exception.type"]).to eq("ExampleException")
                expect(event.attributes["exception.message"]).to eq("oh no!")
                expect(event.attributes["exception.stacktrace"]).to be_a(String)
                expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
                expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
                expect(root_span.attributes["appsignal.tag.method"]).to eq("websocket")
                expect(root_span.attributes["appsignal.tag.path"]).to eq("/blog")
                expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
                  .to eq("action" => "speak", "message" => "foo")
                expect(root_span.attributes).not_to have_key("queue_start")
                expect(last_transaction).to be_completed
              end
            end
          end
        end

        describe "subscribe callback" do
          let(:params) { { "internal" => true } }

          describe "creates a transaction for a subscription" do
            def perform
              instance.subscribe_to_channel
            end

            it "in agent mode", :agent_mode do
              start_agent
              perform

              transaction = last_transaction
              expect(transaction).to have_id
              expect(transaction).to have_action("MyChannel#subscribed")
              expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
              expect(transaction).to_not have_error
              expect(transaction).to include_metadata(
                "method" => "websocket",
                "path" => "/blog"
              )
              expect(transaction).to include_params("internal" => "true")
              expect(transaction).to include_event(
                "body" => "",
                "body_format" => Appsignal::EventFormatter::DEFAULT,
                "count" => 1,
                "name" => "subscribed.action_cable",
                "title" => ""
              )
              expect(transaction).to include_session_data(
                "user_id" => "123",
                "session" => "yes"
              )
              expect(transaction).to include_tags("request_id" => request_id)
              expect(transaction).to_not have_queue_start
              expect(transaction).to be_completed
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(root_span.name).to eq("MyChannel#subscribed")
              expect(root_span.attributes["appsignal.action_name"])
                .to eq("MyChannel#subscribed")
              expect(root_span.attributes["appsignal.namespace"])
                .to eq(Appsignal::Transaction::ACTION_CABLE)
              expect(exception_events).to be_empty
              expect(root_span.attributes["appsignal.tag.method"]).to eq("websocket")
              expect(root_span.attributes["appsignal.tag.path"]).to eq("/blog")
              expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
                .to eq("internal" => "true")
              span = event_spans.find { |s| s.name == "subscribed.action_cable" }
              expect(span).not_to be_nil
              expect(span.parent_span_id).to eq(root_span.span_id)
              expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
                .to eq("user_id" => "123", "session" => "yes")
              expect(root_span.attributes["appsignal.tag.request_id"]).to eq(request_id)
              expect(root_span.attributes).not_to have_key("queue_start")
              expect(last_transaction).to be_completed
            end
          end

          context "without request_id (standalone server)" do
            let(:request_id) { nil }

            describe "sets a generated request ID" do
              def perform
                instance.subscribe_to_channel
              end

              it "in agent mode", :agent_mode do
                start_agent
                perform
                expect(last_transaction).to include_tags("request_id" => kind_of(String))
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform
                expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
              end
            end
          end

          context "with an error in the callback" do
            let(:channel) do
              Class.new(ActionCable::Channel::Base) do
                def subscribed
                  raise ExampleException, "oh no!"
                end

                def self.to_s
                  "MyChannel"
                end
              end
            end

            describe "registers an error on the transaction" do
              def perform
                expect do
                  instance.subscribe_to_channel
                end.to raise_error(ExampleException)
              end

              it "in agent mode", :agent_mode do
                start_agent
                perform

                transaction = last_transaction
                expect(transaction).to have_id
                expect(transaction).to have_action("MyChannel#subscribed")
                expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
                expect(transaction).to have_error("ExampleException", "oh no!")
                expect(transaction).to include_metadata(
                  "method" => "websocket",
                  "path" => "/blog"
                )
                expect(transaction).to include_params("internal" => "true")
                expect(transaction).to include_session_data(
                  "user_id" => "123",
                  "session" => "yes"
                )
                expect(transaction).to_not have_queue_start
                expect(transaction).to be_completed
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

                expect(root_span.attributes["appsignal.action_name"])
                  .to eq("MyChannel#subscribed")
                expect(root_span.attributes["appsignal.namespace"])
                  .to eq(Appsignal::Transaction::ACTION_CABLE)
                event = root_span.events.find { |e| e.name == "exception" }
                expect(event).not_to be_nil
                expect(event.attributes["exception.type"]).to eq("ExampleException")
                expect(event.attributes["exception.message"]).to eq("oh no!")
                expect(event.attributes["exception.stacktrace"]).to be_a(String)
                expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
                expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
                expect(root_span.attributes["appsignal.tag.method"]).to eq("websocket")
                expect(root_span.attributes["appsignal.tag.path"]).to eq("/blog")
                expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
                  .to eq("internal" => "true")
                expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
                  .to eq("user_id" => "123", "session" => "yes")
                expect(root_span.attributes).not_to have_key("queue_start")
                expect(last_transaction).to be_completed
              end
            end
          end

          if DependencyHelper.rails6_present?
            context "with ConnectionStub" do
              let(:connection) { ActionCable::Channel::ConnectionStub.new }

              describe "does not fail on missing `#env` on `ConnectionStub`" do
                def perform
                  instance.subscribe_to_channel
                end

                it "in agent mode", :agent_mode do
                  start_agent
                  perform

                  transaction = last_transaction
                  expect(transaction).to have_id
                  expect(transaction).to have_action("MyChannel#subscribed")
                  expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
                  expect(transaction).to_not have_error
                  expect(transaction).to include_metadata(
                    "method" => "websocket",
                    "path" => "" # No path as the ConnectionStub doesn't have the real request env
                  )
                  expect(transaction).to_not include_params
                  expect(transaction).to include_event(
                    "body" => "",
                    "body_format" => Appsignal::EventFormatter::DEFAULT,
                    "count" => 1,
                    "name" => "subscribed.action_cable",
                    "title" => ""
                  )
                  expect(transaction).to_not have_queue_start
                  expect(transaction).to be_completed
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"])
                    .to eq("MyChannel#subscribed")
                  expect(root_span.attributes["appsignal.namespace"])
                    .to eq(Appsignal::Transaction::ACTION_CABLE)
                  expect(exception_events).to be_empty
                  expect(root_span.attributes["appsignal.tag.method"]).to eq("websocket")
                  expect(root_span.attributes["appsignal.tag.path"]).to eq("")
                  # ConnectionStub has no request env; params are empty in OTel
                  expect(JSON.parse(root_span.attributes.fetch("appsignal.request.payload", "{}")))
                    .to eq({})
                  span = event_spans.find { |s| s.name == "subscribed.action_cable" }
                  expect(span).not_to be_nil
                  expect(span.parent_span_id).to eq(root_span.span_id)
                  expect(root_span.attributes).not_to have_key("queue_start")
                  expect(last_transaction).to be_completed
                end
              end
            end
          end
        end

        describe "unsubscribe callback" do
          let(:params) { { "internal" => true } }

          describe "creates a transaction for an unsubscription" do
            def perform
              instance.unsubscribe_from_channel
            end

            it "in agent mode", :agent_mode do
              start_agent
              perform

              transaction = last_transaction
              expect(transaction).to have_id
              expect(transaction).to have_action("MyChannel#unsubscribed")
              expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
              expect(transaction).to_not have_error
              expect(transaction).to include_metadata(
                "method" => "websocket",
                "path" => "/blog"
              )
              expect(transaction).to include_params("internal" => "true")
              expect(transaction).to include_session_data(
                "user_id" => "123",
                "session" => "yes"
              )
              expect(transaction).to include_event(
                "body" => "",
                "body_format" => Appsignal::EventFormatter::DEFAULT,
                "count" => 1,
                "name" => "unsubscribed.action_cable",
                "title" => ""
              )
              expect(transaction).to_not have_queue_start
              expect(transaction).to be_completed
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(root_span.attributes["appsignal.action_name"])
                .to eq("MyChannel#unsubscribed")
              expect(root_span.attributes["appsignal.namespace"])
                .to eq(Appsignal::Transaction::ACTION_CABLE)
              expect(exception_events).to be_empty
              expect(root_span.attributes["appsignal.tag.method"]).to eq("websocket")
              expect(root_span.attributes["appsignal.tag.path"]).to eq("/blog")
              expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
                .to eq("internal" => "true")
              expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
                .to eq("user_id" => "123", "session" => "yes")
              span = event_spans.find { |s| s.name == "unsubscribed.action_cable" }
              expect(span).not_to be_nil
              expect(span.parent_span_id).to eq(root_span.span_id)
              expect(root_span.attributes).not_to have_key("queue_start")
              expect(last_transaction).to be_completed
            end
          end

          context "without request_id (standalone server)" do
            let(:request_id) { nil }

            describe "sets a generated request ID" do
              def perform
                instance.unsubscribe_from_channel
              end

              it "in agent mode", :agent_mode do
                start_agent
                perform
                expect(last_transaction).to include_tags("request_id" => kind_of(String))
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform
                expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
              end
            end
          end

          context "with an error in the callback" do
            let(:channel) do
              Class.new(ActionCable::Channel::Base) do
                def unsubscribed
                  raise ExampleException, "oh no!"
                end

                def self.to_s
                  "MyChannel"
                end
              end
            end

            describe "registers an error on the transaction" do
              def perform
                expect do
                  instance.unsubscribe_from_channel
                end.to raise_error(ExampleException)
              end

              it "in agent mode", :agent_mode do
                start_agent
                perform

                transaction = last_transaction
                expect(transaction).to have_id
                expect(transaction).to have_action("MyChannel#unsubscribed")
                expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
                expect(transaction).to have_error("ExampleException", "oh no!")
                expect(transaction).to include_metadata(
                  "method" => "websocket",
                  "path" => "/blog"
                )
                expect(transaction).to include_params("internal" => "true")
                expect(transaction).to include_session_data(
                  "user_id" => "123",
                  "session" => "yes"
                )
                expect(transaction).to_not have_queue_start
                expect(transaction).to be_completed
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform

                expect(root_span.attributes["appsignal.action_name"])
                  .to eq("MyChannel#unsubscribed")
                expect(root_span.attributes["appsignal.namespace"])
                  .to eq(Appsignal::Transaction::ACTION_CABLE)
                event = root_span.events.find { |e| e.name == "exception" }
                expect(event).not_to be_nil
                expect(event.attributes["exception.type"]).to eq("ExampleException")
                expect(event.attributes["exception.message"]).to eq("oh no!")
                expect(event.attributes["exception.stacktrace"]).to be_a(String)
                expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
                expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
                expect(root_span.attributes["appsignal.tag.method"]).to eq("websocket")
                expect(root_span.attributes["appsignal.tag.path"]).to eq("/blog")
                expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
                  .to eq("internal" => "true")
                expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
                  .to eq("user_id" => "123", "session" => "yes")
                expect(root_span.attributes).not_to have_key("queue_start")
                expect(last_transaction).to be_completed
              end
            end
          end

          if DependencyHelper.rails6_present?
            context "with ConnectionStub" do
              let(:connection) { ActionCable::Channel::ConnectionStub.new }

              describe "does not fail on missing `#env` on `ConnectionStub`" do
                def perform
                  instance.unsubscribe_from_channel
                end

                it "in agent mode", :agent_mode do
                  start_agent
                  perform

                  transaction = last_transaction
                  expect(transaction).to have_id
                  expect(transaction).to have_action("MyChannel#unsubscribed")
                  expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
                  expect(transaction).to_not have_error
                  expect(transaction).to include_metadata(
                    "method" => "websocket",
                    "path" => "" # No path as the ConnectionStub doesn't have the real request env
                  )
                  expect(transaction).to_not include_params
                  expect(transaction).to include_event(
                    "body" => "",
                    "body_format" => Appsignal::EventFormatter::DEFAULT,
                    "count" => 1,
                    "name" => "unsubscribed.action_cable",
                    "title" => ""
                  )
                  expect(transaction).to_not have_queue_start
                  expect(transaction).to be_completed
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  perform

                  expect(root_span.attributes["appsignal.action_name"])
                    .to eq("MyChannel#unsubscribed")
                  expect(root_span.attributes["appsignal.namespace"])
                    .to eq(Appsignal::Transaction::ACTION_CABLE)
                  expect(exception_events).to be_empty
                  expect(root_span.attributes["appsignal.tag.method"]).to eq("websocket")
                  expect(root_span.attributes["appsignal.tag.path"]).to eq("")
                  # ConnectionStub has no request env; params are empty in OTel
                  expect(JSON.parse(root_span.attributes.fetch("appsignal.request.payload", "{}")))
                    .to eq({})
                  span = event_spans.find { |s| s.name == "unsubscribed.action_cable" }
                  expect(span).not_to be_nil
                  expect(span.parent_span_id).to eq(root_span.span_id)
                  expect(root_span.attributes).not_to have_key("queue_start")
                  expect(last_transaction).to be_completed
                end
              end
            end
          end
        end
      end
    end
  else
    context "without ActionCable" do
      describe ".dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it "returns false" do
          is_expected.to be_falsy
        end
      end
    end
  end
end
