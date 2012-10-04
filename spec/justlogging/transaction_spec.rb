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
      Appsignal::Transaction.create('1', {'SERVER_NAME' => 'localhost'})
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

    describe '#add_exception' do
      let(:exception) {stub(:name => 'test') }

      it 'should add an exception' do
        expect {
          transaction.add_exception(exception)
        }.to change(transaction, :exception).to(exception)
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

    describe '#formatted_exception' do
      let(:exception) do
        stub({
         :backtrace => ['test'],
         :name => 'Appsignal::Error',
         :message => 'nooo'
        })
      end
      before { transaction.add_exception(exception) }
      subject { transaction.formatted_exception }

      it 'should return a formatted exception' do
        should == {
          :backtrace => ['test'],
          :exception => 'Appsignal::Error',
          :message => 'nooo'
        }
      end
    end

    describe '#formatted_events' do
      let(:start_time) { Time.parse('01-01-2001 10:00:00') }
      let(:end_time) { Time.parse('01-01-2001 10:00:01') }
      let(:payload) do
        {
          :name => 'name',
          :duration => 2,
          :time => start_time,
          :end => end_time,
          :payload => {:sensitive => 'data'}
        }
      end
      let(:event) { stub(payload) }

      before { transaction.add_event(event) }

      subject { transaction.formatted_events }

      it 'should return formatted events without the payload' do
        should == [payload.merge(:payload => {})]
      end

      context "when there is a payload sanitizer" do
        subject { transaction.formatted_events.first[:payload] }
        before do
          @old_sanitizer = Appsignal.event_payload_sanitizer
          Appsignal.event_payload_sanitizer = proc do |event|
            {:sanitized => event.payload[:sensitive].reverse }
          end
        end

        it { should == {:sanitized => 'atad'} }

        after do
          Appsignal.event_payload_sanitizer = @old_sanitizer
        end
      end
    end

    describe '#formatted_log_entry' do
      subject { transaction.formatted_log_entry }
      before do
        transaction.stub(:request => mock(:fullpath => '/blog'))
        Rails.stub(:env => 'care about it')
        transaction.stub(:formatted_payload => {:foo => :bar})
      end

      it 'returns a formatted log_entry' do
        should == {
          :name => '/blog',
          :environment => 'care about it',
          :server => 'localhost',
          :kind => 'http_request',
          :foo => :bar
        }
      end
    end

    describe '#formatted_payload' do
      let(:start_time) { Time.parse('01-01-2001 10:00:00') }
      let(:end_time) { Time.parse('01-01-2001 10:00:01') }
      subject { transaction.formatted_payload }

      context "with a present log entry" do
        before do
          transaction.set_log_entry(mock(
            :name => 'name',
            :duration => 2,
            :time => start_time,
            :end => end_time,
            :payload => {
              :controller => 'controller',
              :action => 'action',
              :sensitive => 'data'
            }
          ))
        end

        it 'returns the formatted payload of the log entry' do
          should == {
            :action => 'controller#action',
            :duration => 2,
            :time => start_time,
            :end => end_time
          }
        end

        context "when there is a payload_sanitizer" do
          before do
            @old_sanitizer = Appsignal.event_payload_sanitizer
            Appsignal.event_payload_sanitizer = proc do |event|
              {:sanitized => event.payload[:sensitive].reverse }
            end
          end

          it 'returns the formatted payload of the log entry' do
            should == {
              :action => 'controller#action',
              :duration => 2,
              :time => start_time,
              :end => end_time,
              :sanitized => 'atad'
            }
          end

          after do
            Appsignal.event_payload_sanitizer = @old_sanitizer
          end
        end

      end

      context "without a present log entry" do

        it "returns the exception as the action if there is one" do
          transaction.add_exception(mock(:inspect => '<#exceptional>'))
          should == {:action => 'exceptional'}
        end

        it "returns an empty hash when no exception is set either" do
          should == {}
        end
      end
    end

    describe '#to_hash' do
      subject { transaction.to_hash }
      before { transaction.stub(
        :formatted_log_entry => {:name => 'log_entry'},
        :formatted_events => [{:name => 'event'}],
        :formatted_exception => {:name => 'exception'},
        :failed => false
      )}

      it 'should return a formatted hash of the transaction data' do
        should == {
          :request_id => '1',
          :log_entry => {:name => 'log_entry'},
          :events => [{:name => 'event'}],
          :exception => {:name => 'exception'},
          :failed => false
        }
      end
    end

    describe '#complete!' do
      before { transaction }

      it 'should remove transaction from the queue' do
        expect {
          transaction.complete!
        }.to change(Appsignal.transactions, :length).by(-1)
      end

      context 'calling the appsignal agent' do

        context 'without events and exception' do
          it 'should not add transaction to the agent' do
            Appsignal.agent.should_not_receive(:add_to_queue)
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
  end
end
