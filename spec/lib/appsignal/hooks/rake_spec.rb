require "rake"

describe Appsignal::Hooks::RakeHook do
  let(:task) { Rake::Task.new("task:name", Rake::Application.new) }
  let(:arguments) { Rake::TaskArguments.new(["foo"], ["bar"]) }
  before { start_agent }
  around { |example| keep_transactions { example.run } }

  describe "#execute" do
    context "without error" do
      def perform
        task.execute(arguments)
      end

      context "with :enable_rake_performance_instrumentation == false" do
        before do
          Appsignal.config[:enable_rake_performance_instrumentation] = false
          expect(Appsignal).to_not receive(:stop)
        end

        it "creates no transaction" do
          expect { perform }.to_not(change { created_transactions.count })
        end

        it "calls the original task" do
          expect(perform).to eq([])
        end
      end

      context "with :enable_rake_performance_instrumentation == true" do
        before do
          Appsignal.config[:enable_rake_performance_instrumentation] = true

          # We don't call `and_call_original` here as we don't want AppSignal to
          # stop and start for every spec.
          expect(Appsignal).to receive(:stop).with("rake")
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
      end
    end

    context "with error" do
      before do
        task.enhance { raise ExampleException, "error message" }

        # We don't call `and_call_original` here as we don't want AppSignal to
        # stop and start for every spec.
        expect(Appsignal).to receive(:stop).with("rake")
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
