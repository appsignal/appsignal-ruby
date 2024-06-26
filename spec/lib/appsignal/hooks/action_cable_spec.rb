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
        let(:transaction) do
          Appsignal::Transaction.new(
            transaction_id,
            Appsignal::Transaction::ACTION_CABLE,
            ActionDispatch::Request.new(env)
          )
        end
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
        let(:connection) { ActionCable::Connection::Base.new(server, env) }
        let(:identifier) { { :channel => "MyChannel" }.to_json }
        let(:params) { {} }
        let(:request_id) { SecureRandom.uuid }
        let(:transaction_id) { request_id }
        let(:env) do
          http_request_env_with_data("action_dispatch.request_id" => request_id, :params => params)
        end
        let(:instance) { channel.new(connection, identifier, params) }
        before do
          start_agent
          expect(Appsignal.active?).to be_truthy
          transaction

          set_current_transaction(transaction)

          # Stub transmit call for subscribe/unsubscribe tests
          allow(connection).to receive(:websocket)
            .and_return(instance_double("ActionCable::Connection::WebSocket", :transmit => nil))
        end
        around { |example| keep_transactions { example.run } }

        describe "#perform_action" do
          it "creates a transaction for an action" do
            instance.perform_action("message" => "foo", "action" => "speak")

            transaction = last_transaction
            expect(transaction).to have_id(transaction_id)
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
          end

          context "without request_id (standalone server)" do
            let(:request_id) { nil }
            let(:transaction_id) { SecureRandom.uuid }
            let(:action_transaction) do
              Appsignal::Transaction.new(
                transaction_id,
                Appsignal::Transaction::ACTION_CABLE,
                ActionDispatch::Request.new(env)
              )
            end
            before do
              # Stub future (private AppSignal) transaction id generated by the hook.
              expect(SecureRandom).to receive(:uuid).and_return(transaction_id)
            end

            it "uses its own internal request_id set by the subscribed callback" do
              # Subscribe action, sets the request_id
              instance.subscribe_to_channel
              expect(transaction).to have_id(transaction_id)

              # Expect another transaction for the action.
              # This transaction will use the same request_id as the
              # transaction id used to subscribe to the channel.
              expect(Appsignal::Transaction).to receive(:create).with(
                transaction_id,
                Appsignal::Transaction::ACTION_CABLE,
                kind_of(ActionDispatch::Request)
              ).and_return(action_transaction)
              allow(Appsignal::Transaction).to receive(:current).and_return(action_transaction)

              instance.perform_action("message" => "foo", "action" => "speak")
              expect(action_transaction).to have_id(transaction_id)
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

            it "registers an error on the transaction" do
              expect do
                instance.perform_action("message" => "foo", "action" => "speak")
              end.to raise_error(ExampleException)

              transaction = last_transaction
              expect(transaction).to have_id(transaction_id)
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
            end
          end
        end

        describe "subscribe callback" do
          let(:params) { { "internal" => true } }

          it "creates a transaction for a subscription" do
            instance.subscribe_to_channel

            transaction = last_transaction
            expect(transaction).to have_id(transaction_id)
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
          end

          context "without request_id (standalone server)" do
            let(:request_id) { nil }
            let(:transaction_id) { SecureRandom.uuid }
            before do
              allow(SecureRandom).to receive(:uuid).and_return(transaction_id)
              instance.subscribe_to_channel
            end

            it "uses its own internal request_id" do
              expect(last_transaction).to have_id(transaction_id)
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

            it "registers an error on the transaction" do
              expect do
                instance.subscribe_to_channel
              end.to raise_error(ExampleException)

              transaction = last_transaction
              expect(transaction).to have_id(transaction_id)
              expect(transaction).to have_action("MyChannel#subscribed")
              expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
              expect(transaction).to have_error("ExampleException", "oh no!")
              expect(transaction).to include_metadata(
                "method" => "websocket",
                "path" => "/blog"
              )
              expect(transaction).to include_params("internal" => "true")
            end
          end

          if DependencyHelper.rails6_present?
            context "with ConnectionStub" do
              let(:connection) { ActionCable::Channel::ConnectionStub.new }
              let(:transaction_id) { "Stubbed transaction id" }
              before do
                # Stub future (private AppSignal) transaction id generated by the hook.
                expect(SecureRandom).to receive(:uuid).and_return(transaction_id)
              end

              it "does not fail on missing `#env` method on `ConnectionStub`" do
                instance.subscribe_to_channel

                transaction = last_transaction
                expect(transaction).to have_id(transaction_id)
                expect(transaction).to have_action("MyChannel#subscribed")
                expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
                expect(transaction).to_not have_error
                expect(transaction).to include_metadata(
                  "method" => "websocket",
                  "path" => "" # No path as the ConnectionStub doesn't have the real request env
                )
                expect(transaction).to include_params("internal" => "true")
                expect(transaction).to include_event(
                  "body" => "",
                  "body_format" => Appsignal::EventFormatter::DEFAULT,
                  "count" => 1,
                  "name" => "subscribed.action_cable",
                  "title" => ""
                )
              end
            end
          end
        end

        describe "unsubscribe callback" do
          let(:params) { { "internal" => true } }

          it "creates a transaction for a subscription" do
            instance.unsubscribe_from_channel

            transaction = last_transaction
            expect(transaction).to have_id(transaction_id)
            expect(transaction).to have_action("MyChannel#unsubscribed")
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
              "name" => "unsubscribed.action_cable",
              "title" => ""
            )
          end

          context "without request_id (standalone server)" do
            let(:request_id) { nil }
            let(:transaction_id) { SecureRandom.uuid }
            before do
              allow(SecureRandom).to receive(:uuid).and_return(transaction_id)
              instance.unsubscribe_from_channel
            end

            it "uses its own internal request_id" do
              expect(transaction).to have_id(transaction_id)
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

            it "registers an error on the transaction" do
              expect do
                instance.unsubscribe_from_channel
              end.to raise_error(ExampleException)

              transaction = last_transaction
              expect(transaction).to have_id(transaction_id)
              expect(transaction).to have_action("MyChannel#unsubscribed")
              expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
              expect(transaction).to have_error("ExampleException", "oh no!")
              expect(transaction).to include_metadata(
                "method" => "websocket",
                "path" => "/blog"
              )
              expect(transaction).to include_params("internal" => "true")
            end
          end

          if DependencyHelper.rails6_present?
            context "with ConnectionStub" do
              let(:connection) { ActionCable::Channel::ConnectionStub.new }
              let(:transaction_id) { "Stubbed transaction id" }
              before do
                # Stub future (private AppSignal) transaction id generated by the hook.
                expect(SecureRandom).to receive(:uuid).and_return(transaction_id)
              end

              it "does not fail on missing `#env` method on `ConnectionStub`" do
                instance.unsubscribe_from_channel

                transaction = last_transaction
                expect(transaction).to have_id(transaction_id)
                expect(transaction).to have_action("MyChannel#unsubscribed")
                expect(transaction).to have_namespace(Appsignal::Transaction::ACTION_CABLE)
                expect(transaction).to_not have_error
                expect(transaction).to include_metadata(
                  "method" => "websocket",
                  "path" => "" # No path as the ConnectionStub doesn't have the real request env
                )
                expect(transaction).to include_params("internal" => "true")
                expect(transaction).to include_event(
                  "body" => "",
                  "body_format" => Appsignal::EventFormatter::DEFAULT,
                  "count" => 1,
                  "name" => "unsubscribed.action_cable",
                  "title" => ""
                )
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
