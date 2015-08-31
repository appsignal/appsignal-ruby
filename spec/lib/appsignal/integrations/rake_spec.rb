require 'spec_helper'
require 'rake'
describe "Rack integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/rake.rb') }
  let(:app)  { double(:current_scope => nil) }
  let(:task) { Rake::Task.new('task', app) }
  before do
    load file
    task.stub(
      :name                     => 'task:name',
      :invoke_without_appsignal => true
    )
  end

  describe "#invoke" do
    before { Appsignal.stub(:active? => true) }

    it "should call with appsignal monitoring" do
      expect( task ).to receive(:invoke_with_appsignal).with(['foo'])
    end

    context "when not active" do
      before { Appsignal.stub(:active? => false) }

      it "should NOT call with appsignal monitoring" do
        expect( task ).to_not receive(:invoke_with_appsignal).with(['foo'])
      end

      it "should call the original task" do
        expect( task ).to receive(:invoke_without_appsignal).with(['foo'])
      end
    end

    after { task.invoke(['foo']) }
  end

  describe "#invoke_with_appsignal" do
    context "with transaction" do
      let!(:transaction) { Appsignal::Transaction.new('123', {}) }
      let!(:agent)       { double('Agent', :send_queue => true) }
      before do
        SecureRandom.stub(:uuid => '123')
        Appsignal::Transaction.stub(:create => transaction)
        Appsignal.stub(:agent => agent, :active? => true)
      end

      it "should create a transaction" do
        expect( Appsignal::Transaction ).to receive(:create).with(
          '123',
          ENV,
          :kind => 'background_job',
          :action => 'task:name',
          :params => ['foo']
        )
      end

      it "should call the original task" do
        expect( task ).to receive(:invoke_without_appsignal).with('foo')
      end

      it "should complete the transaction" do
        expect( transaction ).to receive(:complete!)
      end

      it "should send the queue" do
        expect( Appsignal.agent ).to receive(:send_queue)
      end

      context "when Appsignal is not active" do
        before { Appsignal.stub(:active? => false) }

        it "should not send the queue" do
          expect( Appsignal.agent ).to_not receive(:send_queue)
        end
      end

      context "with an exception" do
        let(:exception) { VerySpecificError.new }

        before do
          task.stub(:invoke_without_appsignal).and_raise(exception)
          Appsignal.stub(:is_ignored_exception? => false )
        end

        it "should add the exception to the transaction" do
          expect( transaction ).to receive(:add_exception).with(exception)
        end

        context "when ignored" do
          before { Appsignal.stub(:is_ignored_exception? => true ) }

          it "should NOT add the exception to the transaction" do
            expect( transaction ).to_not receive(:add_exception)
          end
        end
      end
    end

    after { task.invoke_with_appsignal('foo') rescue VerySpecificError }
  end
end
