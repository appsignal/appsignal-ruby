require 'rake'

describe Appsignal::Hooks::RakeHook do
  let(:task) { Rake::Task.new('task:name', Rake::Application.new) }
  before(:all) do
    Appsignal.config = project_fixture_config
    expect(Appsignal.active?).to be_true
    Appsignal::Hooks.load_hooks
  end

  describe "#execute" do
    context "without error" do
      it "creates no transaction" do
        expect(Appsignal::Transaction).to_not receive(:create)
      end

      it "calls the original task" do
        expect(task).to receive(:execute_without_appsignal).with('foo')
      end

      after { task.execute('foo') }
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
        expect(transaction).to receive(:set_action).with('task:name')
      end

      it "sets the error" do
        expect(transaction).to receive(:set_error).with(error)
      end

      it "completes the transaction and stops" do
        expect(transaction).to receive(:complete).ordered
        expect(Appsignal).to receive(:stop).with('rake').ordered
      end

      after do
        expect { task.execute('foo') }.to raise_error VerySpecificError
      end
    end
  end
end
