require 'spec_helper'
require 'rake'
describe "Rack integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/rake.rb') }
  let(:app)  { double(:current_scope => nil) }
  let(:task) { Rake::Task.new('task', app) }
  before do
    load file
  end

  describe "#invoke" do
    before do
      task.stub(
        :name                     => 'task:name',
        :invoke_without_appsignal => true
      )
    end

    it "should create a transaction" do
      expect( Appsignal::Transaction ).to receive(:create)
    end

    context "with transaction" do
      let!(:transaction) { Appsignal::Transaction.new('123', {}) }
      let!(:agent)       { double('Agent', :send_queue => true) }
      before do
        Appsignal::Transaction.stub(:create => transaction)
        Appsignal.stub(:agent => agent, :active? => true)
      end

      it "should set the kind" do
        expect( transaction ).to receive(:set_kind).with('background_job')
      end

      it "should set the action" do
        expect( transaction ).to receive(:set_action).with('task:name')
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

    after { task.invoke('foo') rescue VerySpecificError }
  end
end
