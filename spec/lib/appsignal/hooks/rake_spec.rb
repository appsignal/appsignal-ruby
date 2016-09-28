require 'rake'

describe Appsignal::Hooks::RakeHook do
  let(:app)  { double(:current_scope => nil) }
  let(:task) { Rake::Task.new('task', app) }
  before do
    task.stub(
      :name                      => 'task:name',
      :execute_without_appsignal => true
    )
  end
  before :all do
    Appsignal::Hooks::RakeHook.new.install
  end

  describe "#execute" do
    context "with transaction" do
      let!(:transaction) { background_job_transaction }
      let!(:agent)       { double('Agent', :send_queue => true) }
      before do
        transaction.stub(:set_action)
        transaction.stub(:set_error)
        transaction.stub(:complete)
        SecureRandom.stub(:uuid => '123')
        Appsignal::Transaction.stub(:create => transaction)
        Appsignal.stub(:active? => true)
      end

      it "should call the original task" do
        expect( task ).to receive(:execute_without_appsignal).with('foo')
      end

      it "should not create a transaction" do
        expect( Appsignal::Transaction ).not_to receive(:create)
      end

      context "with an exception" do
        let(:exception) { VerySpecificError.new }

        before do
          task.stub(:execute_without_appsignal).and_raise(exception)
        end

        it "should create a transaction" do
          expect( Appsignal::Transaction ).to receive(:create).with(
            '123',
            Appsignal::Transaction::BACKGROUND_JOB,
            kind_of(Appsignal::Transaction::GenericRequest)
          )
        end

        it "should set the action on the transaction" do
          expect( transaction ).to receive(:set_action).with('task:name')
        end

        it "should add the exception to the transaction" do
          expect( transaction ).to receive(:set_error).with(exception)
        end

        it "should call complete! on the transaction" do
          expect( transaction ).to receive(:complete)
        end

        it "should stop appsignal" do
          expect( Appsignal ).to receive(:stop)
        end
      end
    end

    after { task.execute('foo') rescue VerySpecificError }
  end
end
