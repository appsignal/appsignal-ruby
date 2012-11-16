require 'spec_helper'

describe Appsignal::Transaction do
  describe '.create' do
    before { Appsignal::Transaction.create('1', {}) }

    it 'should add the id to the thread' do
      Thread.current[:appsignal_transaction_id].should == '1'
    end

    it 'should add the transaction to the list' do
      Appsignal.transactions['1'].should be_a Appsignal::Transaction
    end
  end

  describe '.current' do
    let(:transaction) { Appsignal::Transaction.create('1', {}) }
    before { transaction }
    subject { Appsignal::Transaction.current }

    it 'should return the correct transaction' do
      should eq transaction
    end
  end

  describe 'transaction instance' do
    let(:transaction) do
      Appsignal::Transaction.create('1', {
        'HTTP_USER_AGENT' => 'IE6',
        'SERVER_NAME' => 'localhost',
        'action_dispatch.routes' => 'not_available'
      })
    end

    describe '#request' do
      subject { transaction.request }

      it { should be_a ActionDispatch::Request }
    end

    describe '#set_log_entry' do
      let(:log_entry) {stub(:name => 'test') }

      it 'should add a log entry' do
        expect {
          transaction.set_log_entry(log_entry)
        }.to change(transaction, :log_entry).to(log_entry)
      end
    end

    describe '#add_event' do
      let(:event) {stub(:name => 'test') }

      it 'should add a log entry' do
        expect {
          transaction.add_event(event)
        }.to change(transaction, :events).to([event])
      end
    end

    describe '#add_exception' do
      let(:exception) {stub(:name => 'test') }

      it 'should add an exception' do
        expect {
          transaction.add_exception(exception)
        }.to change(transaction, :exception).to(exception)
      end
    end

    describe "#hostname" do
      before { Socket.stub(:gethostname => 'app1.local') }

      subject { transaction.hostname }

      it { should == 'app1.local' }
    end

    describe '#slow_request?' do
      let(:duration) { 199 }
      subject { transaction.slow_request? }
      before { transaction.set_log_entry(stub(:duration => duration)) }

      it { should be_false }

      context "when the request took long" do
        let(:duration) { 200 }

        it { should be_true }
      end

      context "when log entry is empty" do
        before { transaction.set_log_entry(nil) }

        it "should not raise an error" do
          expect {
            transaction.slow_request?
          }.to_not raise_error
        end
      end
    end

    describe '#to_hash' do
      subject { transaction.to_hash }
      before { transaction.stub(:exception? => false) }

      context "with an exception request" do
        before { transaction.stub(:exception? => true) }

        it "calls TransactionFormatter.faulty with self" do
          Appsignal::TransactionFormatter.should_receive(:faulty).
            with(transaction).and_return({})
        end
      end

      context "with a slow request" do
        before { transaction.stub(:slow_request? => true) }

        it "calls TransactionFormatter.slow with self" do
          Appsignal::TransactionFormatter.should_receive(:slow).
            with(transaction).and_return({})
        end
      end

      context "with a regular request" do
        before { transaction.stub(:slow_request? => false) }

        it "calls TransactionFormatter.slow with self" do
          Appsignal::TransactionFormatter.should_receive(:regular).
            with(transaction).and_return({})
        end
      end

      after { subject }
    end

    describe '#complete!' do
      before { transaction.stub(:to_hash => {}) }
      before { transaction.set_log_entry(stub(:duration => 199, :time => Time.now)) }

      it 'should remove transaction from the queue' do
        expect {
          transaction.complete!
        }.to change(Appsignal.transactions, :length).by(-1)
      end

      context 'calling the appsignal agent' do

        context 'without events and exception (fast request)' do
          it 'should add transaction to the agent' do
            Appsignal.agent.should_receive(:add_to_queue)
          end
        end

        context 'with events' do
          before { transaction.add_event(stub) }
          before { transaction.stub(:to_hash => {})}

          it 'should add transaction to the agent' do
            Appsignal.agent.should_receive(:add_to_queue)
          end
        end

        context 'with exception' do
          before { transaction.add_exception(stub) }
          before { transaction.stub(:to_hash => {})}

          it 'should add transaction to the agent' do
            Appsignal.agent.should_receive(:add_to_queue)
          end
        end

        after { transaction.complete! }
      end

      context 'thread' do
        before { transaction.complete! }

        it 'should reset the thread transaction id' do
          Thread.current[:appsignal_transaction_id].should be_nil
        end
      end
    end

    describe '#complete_trace!' do
      context 'calling the appsignal agent' do

        context 'with log_entry' do
          before do
            transaction.set_log_entry(
              {:duration => 199, :kind => 'background'}
            )
          end

          it 'should add transaction to the agent' do
            Appsignal.agent.should_receive(:add_to_queue).
              with({:duration => 199, :kind => 'background'})
          end
        end

        context 'with exception' do
          before do
            transaction.add_exception(
              {:exception => 'Error', :kind => 'background'}
            )
          end

          it 'should add transaction to the agent' do
            Appsignal.agent.should_receive(:add_to_queue).
              with({:exception => 'Error', :kind => 'background'})
          end
        end

        after { transaction.complete_trace! }
      end

      context 'thread' do
        before { transaction.complete_trace! }

        it 'should reset the thread transaction id' do
          Thread.current[:appsignal_transaction_id].should be_nil
        end
      end
    end
  end
end
