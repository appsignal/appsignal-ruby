require "rake"

describe Appsignal::Hooks::RakeHook do
  let(:helper) { Appsignal::Integrations::RakeIntegrationHelper }
  let(:task) { Rake::Task.new("task:name", Rake::Application.new) }
  let(:arguments) { Rake::TaskArguments.new(["foo"], ["bar"]) }
  before do
    start_agent
    allow(Kernel).to receive(:at_exit)
  end
  around { |example| keep_transactions { example.run } }
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
        before do
          Appsignal.config[:enable_rake_performance_instrumentation] = false
        end

        it "creates no transaction" do
          expect { perform }.to_not(change { created_transactions.count })
        end

        it "calls the original task" do
          expect(perform).to eq([])
        end

        it "does not register an at_exit hook" do
          perform
          expect_to_not_have_registered_at_exit_hook
        end
      end

      context "with :enable_rake_performance_instrumentation == true" do
        before do
          Appsignal.config[:enable_rake_performance_instrumentation] = true
        end

        it "creates a transaction" do
          expect { perform }.to(change { created_transactions.count }.by(1))

          transaction = last_transaction
          expect(transaction).to have_id
          expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
          expect(transaction).to have_action("task:name")
          expect(transaction).to_not have_error
          expect(transaction).to include_params("foo" => "bar")
          expect(transaction).to include_event("name" => "task.rake")
          expect(transaction).to be_completed
        end

        it "calls the original task" do
          expect(perform).to eq([])
        end

        it "registers an at_exit hook" do
          perform
          expect_to_have_registered_at_exit_hook
        end
      end
    end

    context "with error" do
      before do
        task.enhance { raise ExampleException, "error message" }
      end

      def perform
        expect { task.execute(arguments) }.to raise_error(ExampleException, "error message")
      end

      it "creates a background job transaction" do
        perform

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
        expect(transaction).to have_action("task:name")
        expect(transaction).to have_error("ExampleException", "error message")
        expect(transaction).to include_params("foo" => "bar")
        expect(transaction).to be_completed
      end

      it "registers an at_exit hook" do
        perform
        expect_to_have_registered_at_exit_hook
      end

      context "when first argument is not a `Rake::TaskArguments`" do
        let(:arguments) { nil }

        it "does not add the params to the transaction" do
          perform

          expect(last_transaction).to_not include_params
        end
      end
    end
  end
end

describe "Appsignal::Integrations::RakeIntegrationHelper" do
  let(:helper) { Appsignal::Integrations::RakeIntegrationHelper }
  describe ".register_at_exit_hook" do
    before do
      start_agent
      allow(Appsignal).to receive(:stop)
    end

    it "registers the at_exit hook only once" do
      allow(Kernel).to receive(:at_exit)
      helper.register_at_exit_hook
      helper.register_at_exit_hook
      expect(Kernel).to have_received(:at_exit).once
    end
  end

  describe ".at_exit_hook" do
    let(:helper) { Appsignal::Integrations::RakeIntegrationHelper }
    before do
      start_agent
      allow(Appsignal).to receive(:stop)
    end

    it "calls Appsignal.stop" do
      helper.at_exit_hook
      expect(Appsignal).to have_received(:stop).with("rake")
    end
  end
end
