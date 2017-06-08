describe Appsignal::Hooks::ActionCableHook do
  if DependencyHelper.action_cable_present?
    context "with ActionCable" do
      require "action_cable/engine"

      describe ".dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it "returns true" do
          is_expected.to be_truthy
        end
      end

      describe ActionCable::Channel::Base do
        let(:transaction) do
          Appsignal::Transaction.new(
            request_id,
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
            s.config.logger = Logger.new(log)
          end
        end
        let(:connection) { ActionCable::Connection::Base.new(server, env) }
        let(:identifier) { { :channel => "MyChannel" }.to_json }
        let(:params) { {} }
        let(:request_id) { SecureRandom.uuid }
        let(:env) do
          http_request_env_with_data("action_dispatch.request_id" => request_id, :params => params)
        end
        let(:instance) { channel.new(connection, identifier, params) }
        subject { transaction.to_h }
        before do
          start_agent
          expect(Appsignal.active?).to be_truthy
          transaction

          expect(Appsignal::Transaction).to receive(:create)
            .with(request_id, Appsignal::Transaction::ACTION_CABLE, kind_of(ActionDispatch::Request))
            .and_return(transaction)
          allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
          expect(transaction.ext).to receive(:complete) # and do nothing

          # TODO: Nicer way to stub this without a websocket?
          allow(connection).to receive(:websocket).and_return(double(:transmit => nil))
        end

        describe "#perform_action" do
          it "creates a transaction for an action" do
            instance.perform_action("message" => "foo", "action" => "speak")

            expect(subject).to include(
              "action" => "MyChannel#speak",
              "error" => nil,
              "id" => request_id,
              "namespace" => Appsignal::Transaction::ACTION_CABLE,
              "metadata" => {
                "method" => "websocket",
                "path" => "/blog"
              }
            )
            expect(subject["sample_data"]).to include(
              "params" => {
                "action" => "speak",
                "message" => "foo"
              }
            )
          end

          context "with an error in the action" do
            let(:channel) do
              Class.new(ActionCable::Channel::Base) do
                def speak(_data)
                  raise VerySpecificError, "oh no!"
                end

                def self.to_s
                  "MyChannel"
                end
              end
            end

            it "registers an error on the transaction" do
              expect do
                instance.perform_action("message" => "foo", "action" => "speak")
              end.to raise_error(VerySpecificError)

              expect(subject).to include(
                "action" => "MyChannel#speak",
                "id" => request_id,
                "namespace" => Appsignal::Transaction::ACTION_CABLE,
                "metadata" => {
                  "method" => "websocket",
                  "path" => "/blog"
                }
              )
              expect(subject["error"]).to include(
                "backtrace" => kind_of(String),
                "name" => "VerySpecificError",
                "message" => "oh no!"
              )
              expect(subject["sample_data"]).to include(
                "params" => {
                  "action" => "speak",
                  "message" => "foo"
                }
              )
            end
          end
        end

        describe "subscribe callback" do
          let(:params) { { "internal" => true } }

          it "creates a transaction for a subscription" do
            instance.subscribe_to_channel

            expect(subject).to include(
              "action" => "MyChannel#subscribed",
              "error" => nil,
              "id" => request_id,
              "namespace" => Appsignal::Transaction::ACTION_CABLE,
              "metadata" => {
                "method" => "websocket",
                "path" => "/blog"
              }
            )
            expect(subject["sample_data"]).to include(
              "params" => { "internal" => "true" }
            )
          end

          context "with an error in the callback" do
            let(:channel) do
              Class.new(ActionCable::Channel::Base) do
                def subscribed
                  raise VerySpecificError, "oh no!"
                end

                def self.to_s
                  "MyChannel"
                end
              end
            end

            it "registers an error on the transaction" do
              expect do
                instance.subscribe_to_channel
              end.to raise_error(VerySpecificError)

              expect(subject).to include(
                "action" => "MyChannel#subscribed",
                "id" => request_id,
                "namespace" => Appsignal::Transaction::ACTION_CABLE,
                "metadata" => {
                  "method" => "websocket",
                  "path" => "/blog"
                }
              )
              expect(subject["error"]).to include(
                "backtrace" => kind_of(String),
                "name" => "VerySpecificError",
                "message" => "oh no!"
              )
              expect(subject["sample_data"]).to include(
                "params" => { "internal" => "true" }
              )
            end
          end
        end

        describe "unsubscribe callback" do
          let(:params) { { "internal" => true } }

          it "creates a transaction for a subscription" do
            instance.unsubscribe_from_channel

            expect(subject).to include(
              "action" => "MyChannel#unsubscribed",
              "error" => nil,
              "id" => request_id,
              "namespace" => Appsignal::Transaction::ACTION_CABLE,
              "metadata" => {
                "method" => "websocket",
                "path" => "/blog"
              }
            )
            expect(subject["sample_data"]).to include(
              "params" => { "internal" => "true" }
            )
          end

          context "with an error in the callback" do
            let(:channel) do
              Class.new(ActionCable::Channel::Base) do
                def unsubscribed
                  raise VerySpecificError, "oh no!"
                end

                def self.to_s
                  "MyChannel"
                end
              end
            end

            it "registers an error on the transaction" do
              expect do
                instance.unsubscribe_from_channel
              end.to raise_error(VerySpecificError)

              expect(subject).to include(
                "action" => "MyChannel#unsubscribed",
                "id" => request_id,
                "namespace" => Appsignal::Transaction::ACTION_CABLE,
                "metadata" => {
                  "method" => "websocket",
                  "path" => "/blog"
                }
              )
              expect(subject["error"]).to include(
                "backtrace" => kind_of(String),
                "name" => "VerySpecificError",
                "message" => "oh no!"
              )
              expect(subject["sample_data"]).to include(
                "params" => { "internal" => "true" }
              )
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
