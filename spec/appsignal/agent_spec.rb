require 'spec_helper'

describe Appsignal::Agent do
  let(:transaction) { stub(
    :name => 'transaction',
    :exception? => false,
    :action => 'something#else'
  ) }

  describe '#add_to_queue' do
    before do
      start = Time.now
      @agent = Appsignal::Agent.new
      @exception_transaction = transaction_with_exception
      @slow_transaction = slow_transaction(
        :process_action_event => notification_event(
          :name => 'slow',
          :start => start,
          :ending => start + 250.0,
          :payload => create_payload(
            :action => 'action1',
            :controller => 'controller'
          )
        )
      )
      @slower_transaction = slow_transaction(
        :process_action_event => notification_event(
          :name => 'slow',
          :start => start,
          :ending => start + 350.0,
          :payload => create_payload(
            :action => 'action1',
            :controller => 'controller'
          )
        )
      )
      @other_slow_transaction = slow_transaction(
        :process_action_event => notification_event(
          :name => 'slow',
          :start => start,
          :ending => start + 260.0,
          :payload => create_payload(
            :action => 'action1',
            :controller => 'controller'
          )
        )
      )
      @slow_transaction_in_other_action = slow_transaction(
        :process_action_event => notification_event(
          :name => 'slow',
          :start => start,
          :ending => start + 400.0,
          :payload => create_payload(
            :action => 'action2',
            :controller => 'controller'
          )
        )
      )
    end
    subject { @agent }

    context "an exception transaction" do
      before do
        @exception_transaction.should_not_receive(:clear_payload_and_events!)
        subject.add_to_queue(@exception_transaction)
      end

      its(:queue) { should include(@exception_transaction) }
      its(:slowest_transactions) { should be_empty }

      context "a slow transaction" do
        before do
          subject.add_to_queue(@slow_transaction)
        end

        its(:queue) { should include(@slow_transaction) }
        its(:slowest_transactions) { should == {
          'controller#action1' => @slow_transaction
        } }

        context "a slower transaction in the same action" do
          before do
            @slow_transaction.should_receive(:clear_payload_and_events!)
            @slower_transaction.should_not_receive(:clear_payload_and_events!)
            subject.add_to_queue(@slower_transaction)
          end

          its(:queue) { should include(@slower_transaction) }
          its(:slowest_transactions) { should == {
            'controller#action1' => @slower_transaction
          } }

          context "a slow but not the slowest transaction in the same action" do
            before do
              @other_slow_transaction.should_receive(:clear_payload_and_events!)
              subject.add_to_queue(@other_slow_transaction)
            end

            its(:queue) { should include(@other_slow_transaction) }
            its(:slowest_transactions) { should == {
              'controller#action1' => @slower_transaction
            } }
          end

          context "an even slower transaction in a different action" do
            before do
              @slow_transaction_in_other_action.should_not_receive(:clear_payload_and_events!)
              subject.add_to_queue(@slow_transaction_in_other_action)
            end

            its(:queue) { should include(@slow_transaction_in_other_action) }
            its(:slowest_transactions) { should == {
              'controller#action1' => @slower_transaction,
              'controller#action2' => @slow_transaction_in_other_action
            } }
          end
        end
      end
    end
  end

  describe "#send_queue" do
    it "transmits" do
      subject.stub(:queue => [stub(:to_hash => 'foo')])
      subject.transmitter.should_receive(:transmit).with(['foo'])
    end

    it "handles the return code" do
      subject.transmitter.stub(:transmit => '200')
      subject.should_receive(:handle_result).with('200')
    end

    it "handles exceptions in transmit" do
      subject.transmitter.stub(:transmit).and_raise(Exception.new)
      subject.should_receive(:handle_result).with(nil)
      Appsignal.logger.should_receive(:error).with('Exception while communicating with AppSignal: Exception')
    end

    after { subject.send_queue }
  end

  describe '#handle_result' do
    before { subject.add_to_queue(transaction) }
    before { subject.instance_variable_set(:@sleep_time, 3.0) }

    context "good responses" do
      before { subject.handle_result(code) }

      context "with 200" do
        let(:code) { '200' }

        its(:queue) { should be_empty }
        its(:slowest_transactions) { should be_empty }
      end

      context "with 420" do
        let(:code) { '420' }

        its(:queue) { should be_empty }
        its(:slowest_transactions) { should be_empty }
        its(:sleep_time) { should == 4.5 }
      end

      context "with 413" do
        let(:code) { '413' }

        its(:queue) { should be_empty }
        its(:slowest_transactions) { should be_empty }
        its(:sleep_time) { should == 2.0 }
      end
    end

    context "bad responses" do
      context "with 429" do
        let(:code) { '429' }

        it "calls a stop to logging" do
          subject.should_receive :stop_logging
        end
      end

      context "with 406" do
        let(:code) { '406' }

        it "calls a stop to logging" do
          subject.should_receive :stop_logging
        end
      end

      context "with 402" do
        let(:code) { '402' }

        it "calls a stop to logging" do
          subject.should_receive :stop_logging
        end
      end

      context "with 401" do
        let(:code) { '401' }

        it "calls a stop to logging" do
          subject.should_receive :stop_logging
        end
      end

      context "any other response" do
        let(:code) { 'any other response' }

        it "calls retry_once" do
          subject.should_receive :retry_once
        end
      end

      after { subject.handle_result(code) }
    end
  end

  describe "#good_response" do
    before do
      subject.instance_variable_set(:@retry_once, false)
      subject.add_to_queue(transaction)
      subject.send :good_response
    end

    its(:queue) { should be_empty }
    its(:slowest_transactions) { should be_empty }

    it "allows the next request to be retried" do
      subject.instance_variable_get(:@retry_request).should be_true
    end
  end

  describe "#retry_once" do
    before do
      subject.add_to_queue(transaction)
      subject.send :retry_once
    end

    context "on time," do
      its(:queue) { should == [transaction] }
      its(:slowest_transactions) { should == {
        'something#else' => transaction
      } }

      context "two times" do
        before { subject.send :retry_once }

        its(:queue) { should be_empty }
      end
    end
  end

  describe "#stop_logging" do
    it "does not raise exceptions" do
      expect { subject.send :stop_logging }.not_to raise_error
    end
  end

  describe "when inactive" do
    before { Appsignal.stub(:active? => false) }

    it "should not start a new thread" do
      Thread.should_not_receive(:new)
    end

    after { Appsignal::Agent.new }
  end
end
