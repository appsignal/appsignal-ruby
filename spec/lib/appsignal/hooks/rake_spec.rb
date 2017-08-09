require "rake"

describe Appsignal::Hooks::RakeHook do
  let(:task) { Rake::Task.new("task:name", Rake::Application.new) }
  let(:arguments) { Rake::TaskArguments.new(["foo"], ["bar"]) }
  let(:genric_request) { Appsignal::Transaction::GenericRequest.new({}) }
  before(:context) do
    Appsignal.config = project_fixture_config
    expect(Appsignal.active?).to be_truthy
    Appsignal::Hooks.load_hooks
  end

  describe "#execute" do
    context "without error" do
      it "creates no transaction" do
        expect(Appsignal::Transaction).to_not receive(:create)
      end

      it "calls the original task" do
        expect(task).to receive(:execute_without_appsignal).with("foo")
      end

      after { task.execute("foo") }
    end

    context "with error" do
      let(:error) { VerySpecificError.new }
      let(:transaction) { background_job_transaction }
      before do
        task.enhance { raise error }

        expect(Appsignal::Transaction).to receive(:create).with(
          kind_of(String),
          Appsignal::Transaction::BACKGROUND_JOB,
          kind_of(Appsignal::Transaction::GenericRequest)
        ).and_return(transaction)
      end

      it "sets the action" do
        expect(transaction).to receive(:set_action).with("task:name")
      end

      it "sets the error" do
        expect(transaction).to receive(:set_error).with(error)
      end

      it "completes the transaction and stops" do
        expect(transaction).to receive(:complete).ordered
        expect(Appsignal).to receive(:stop).with("rake").ordered
      end

      it "adds the task arguments to the request" do
        expect(Appsignal::Transaction::GenericRequest).to receive(:new)
          .with(:params => { :foo => "bar" })
          .and_return(genric_request)
      end

      context "when first argument is not a `Rake::TaskArguments`" do
        let(:arguments) { nil }

        it "adds the first argument regardless" do
          expect(Appsignal::Transaction::GenericRequest).to receive(:new)
            .with(:params => nil)
            .and_return(genric_request)
        end
      end

      after do
        expect { task.execute(arguments) }.to raise_error VerySpecificError
      end
    end
  end
end
