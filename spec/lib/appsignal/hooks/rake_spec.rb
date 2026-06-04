require "rake"

describe Appsignal::Hooks::RakeHook do
  let(:helper) { Appsignal::Integrations::RakeIntegrationHelper }
  let(:task) { Rake::Task.new("task:name", Rake::Application.new) }
  let(:arguments) { Rake::TaskArguments.new(["foo"], ["bar"]) }
  let(:options) { {} }
  # The mode contexts run `start_agent`; thread the Rake options through them.
  let(:start_agent_args) { { :options => options } }
  before { allow(Kernel).to receive(:at_exit) }
  after do
    if helper.instance_variable_defined?(:@register_at_exit_hook)
      helper.remove_instance_variable(:@register_at_exit_hook)
    end
  end

  def expect_to_not_have_registered_at_exit_hook
    expect(Kernel).to_not have_received(:at_exit)
  end

  def expect_to_have_registered_at_exit_hook
    expect(Kernel).to have_received(:at_exit)
  end

  describe "#execute" do
    context "without error" do
      def perform
        task.execute(arguments)
      end

      context "with :enable_rake_performance_instrumentation == false" do
        let(:options) { { :enable_rake_performance_instrumentation => false } }

        it_in_both_modes "creates no transaction" do
          expect { perform }.to_not(change { created_transactions.count })
        end

        it_in_both_modes "calls the original task" do
          expect(perform).to eq([])
        end

        it_in_both_modes "does not register an at_exit hook" do
          perform
          expect_to_not_have_registered_at_exit_hook
        end
      end

      context "with :enable_rake_performance_instrumentation == true" do
        let(:options) { { :enable_rake_performance_instrumentation => true } }

        describe "creates a transaction" do
          it "in agent mode", :agent_mode do
            expect { perform }.to(change { created_transactions.count }.by(1))

            transaction = last_transaction
            expect(transaction).to have_id
            expect(transaction).to have_namespace("rake")
            expect(transaction).to have_action("task:name")
            expect(transaction).to_not have_error
            expect(transaction).to include_params("foo" => "bar")
            expect(transaction).to include_event("name" => "task.rake")
            expect(transaction).to be_completed
          end

          it "in collector mode", :collector_mode do
            expect { perform }.to(change { created_transactions.count }.by(1))

            # NOTE: params (include_params) is a collector-mode gap --
            # set_sample_data is not yet implemented in the OpenTelemetry backend.
            expect(root_span.attributes["appsignal.namespace"]).to eq("rake")
            expect(root_span.name).to eq("task:name")
            expect(root_span.attributes["appsignal.action_name"]).to eq("task:name")
            expect(exception_events).to be_empty
            expect(event_spans.map(&:name)).to include("task.rake")
            expect(last_transaction).to be_completed
          end
        end

        it_in_both_modes "calls the original task" do
          expect(perform).to eq([])
        end

        it_in_both_modes "registers an at_exit hook" do
          perform
          expect_to_have_registered_at_exit_hook
        end
      end
    end

    context "with error" do
      before do
        task.enhance { raise error }
      end

      def perform
        expect { task.execute(arguments) }.to raise_error(error)
      end

      context "with normal error" do
        let(:error) { ExampleException.new("error message") }

        describe "creates a background job transaction" do
          it "in agent mode", :agent_mode do
            perform

            transaction = last_transaction
            expect(transaction).to have_id
            expect(transaction).to have_namespace("rake")
            expect(transaction).to have_action("task:name")
            expect(transaction).to have_error("ExampleException", "error message")
            expect(transaction).to include_params("foo" => "bar")
            expect(transaction).to be_completed
          end

          it "in collector mode", :collector_mode do
            perform

            # NOTE: params (include_params) is a collector-mode gap --
            # set_sample_data is not yet implemented in the OpenTelemetry backend.
            expect(root_span.attributes["appsignal.namespace"]).to eq("rake")
            expect(root_span.name).to eq("task:name")
            expect(root_span.attributes["appsignal.action_name"]).to eq("task:name")

            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("ExampleException")
            expect(event.attributes["exception.message"]).to eq("error message")
            expect(event.attributes["exception.stacktrace"]).to be_a(String)
            expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
            expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
            expect(last_transaction).to be_completed
          end
        end

        it_in_both_modes "registers an at_exit hook" do
          perform
          expect_to_have_registered_at_exit_hook
        end

        context "when first argument is not a `Rake::TaskArguments`" do
          let(:arguments) { nil }

          # Agent-only: asserting on params is a collector-mode gap
          # (set_sample_data is not yet implemented in the OpenTelemetry backend).
          it "does not add the params to the transaction", :agent_mode do
            perform

            expect(last_transaction).to_not include_params
          end
        end
      end

      context "when error is a SystemExit" do
        let(:error) { SystemExit.new(1) }

        describe "does not report the error" do
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

      context "when error is a SignalException" do
        let(:error) { SignalException.new(1) }

        describe "does not report the error" do
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
  end
end

describe "Appsignal::Integrations::RakeIntegrationHelper" do
  let(:helper) { Appsignal::Integrations::RakeIntegrationHelper }
  describe ".register_at_exit_hook" do
    before { allow(Appsignal).to receive(:stop) }
    # Reset the memoized registration flag so each example (including the
    # agent/collector pair) starts fresh.
    after do
      if helper.instance_variable_defined?(:@register_at_exit_hook)
        helper.remove_instance_variable(:@register_at_exit_hook)
      end
    end

    it_in_both_modes "registers the at_exit hook only once" do
      allow(Kernel).to receive(:at_exit)
      helper.register_at_exit_hook
      helper.register_at_exit_hook
      expect(Kernel).to have_received(:at_exit).once
    end
  end

  describe ".at_exit_hook" do
    let(:helper) { Appsignal::Integrations::RakeIntegrationHelper }
    before { allow(Appsignal).to receive(:stop) }

    it_in_both_modes "calls Appsignal.stop" do
      helper.at_exit_hook
      expect(Appsignal).to have_received(:stop).with("rake")
    end
  end
end
