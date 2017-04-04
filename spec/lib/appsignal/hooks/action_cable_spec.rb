describe Appsignal::Hooks::ActionCableHook do
  if DependencyHelper.action_cable_present?
    context "with ActionCable" do
      require "action_cable/engine"

      before do
        Appsignal.config = project_fixture_config
        expect(Appsignal.active?).to be_truthy
        Appsignal::Hooks.load_hooks
      end

      describe ".dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it "returns true" do
          is_expected.to be_truthy
        end
      end

      describe ".install" do
        it "installs the ActionCable subscriber" do
          listeners =
            ActiveSupport::Notifications.notifier.listeners_for("perform_action.action_cable")
          expect(listeners).to_not be_empty
        end
      end

      describe Appsignal::Hooks::ActionCableHook::Subscriber do
        context "without action_cable events" do
          it "does not register the event" do
            expect(Appsignal::Transaction).to_not receive(:create)

            ActiveSupport::Notifications.instrument("perform_action.foo") do
              # nothing
            end
          end
        end

        context "with action_cable events" do
          let(:transaction) do
            instance_double "Appsignal::Transaction",
              :set_http_or_background_action => nil,
              :set_http_or_background_queue_start => nil,
              :set_metadata => nil,
              :set_action => nil,
              :set_action_if_nil => nil,
              :set_error => nil,
              :start_event => nil,
              :finish_event => nil,
              :complete => nil
          end
          let(:payload) do
            {
              :channel_class => "ChannelClass",
              :action => "channel_action",
              :data => { :foo => :bar }
            }.tap do |hash|
              hash[:exception_object] = exception if defined?(exception)
            end
          end
          before do
            expect(Appsignal::Transaction).to receive(:create)
              .with(kind_of(String), Appsignal::Transaction::ACTION_CABLE, kind_of(Hash))
              .and_return(transaction)
            allow(Appsignal::Transaction).to receive(:current).and_return(transaction)
          end
          after do
            ActiveSupport::Notifications.instrument("perform_action.action_cable", payload) do
              # nothing
            end
          end

          shared_examples "a ActionCable transaction" do
            it "starts and completes a transaction for perform_action.action_cable events" do
              expect(transaction).to receive(:set_action_if_nil).with("ChannelClass#channel_action")
              expect(transaction).to receive(:set_metadata).with("method", "websocket")
              expect(transaction).to receive(:complete)
            end
          end

          it_behaves_like "a ActionCable transaction"

          context "with an exception" do
            let(:exception) { VerySpecificError }

            it_behaves_like "a ActionCable transaction"

            it "registers the exception" do
              expect(transaction).to receive(:set_error).with(exception)
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
