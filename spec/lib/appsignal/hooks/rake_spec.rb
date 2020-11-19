require "rake"

describe Appsignal::Hooks::RakeHook do
  let(:task) { Rake::Task.new("task:name", Rake::Application.new) }
  let(:arguments) { Rake::TaskArguments.new(["foo"], ["bar"]) }
  let(:generic_request) { Appsignal::Transaction::GenericRequest.new({}) }
  before(:context) { start_agent }

  describe "#execute" do
    context "without error" do
      before { expect(Appsignal).to_not receive(:stop) }

      def perform
        task.execute(arguments)
      end

      it "creates no transaction" do
        expect(Appsignal::Transaction).to_not receive(:new)
        expect { perform }.to_not(change { created_transactions })
      end

      it "calls the original task" do
        expect(perform).to eq([])
      end
    end

    context "with error" do
      let(:error) { ExampleException }
      before do
        task.enhance { raise error, "my error message" }
        # We don't call `and_call_original` here as we don't want AppSignal to
        # stop and start for every spec.
        expect(Appsignal).to receive(:stop).with("rake")
      end

      def perform
        keep_transactions do
          expect { task.execute(arguments) }.to raise_error(error)
        end
      end

      it "creates a background job transaction" do
        perform

        expect(last_transaction).to be_completed
        expect(last_transaction.to_h).to include(
          "id" => kind_of(String),
          "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
          "action" => "task:name",
          "error" => {
            "name" => "ExampleException",
            "message" => "my error message",
            "backtrace" => kind_of(String)
          },
          "sample_data" => hash_including(
            "params" => { "foo" => "bar" }
          )
        )
      end

      context "when first argument is not a `Rake::TaskArguments`" do
        let(:arguments) { nil }

        it "does not add the params to the transaction" do
          perform

          expect(last_transaction.to_h).to include(
            "sample_data" => hash_excluding("params")
          )
        end
      end
    end
  end
end
