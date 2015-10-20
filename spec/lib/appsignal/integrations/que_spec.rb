require 'spec_helper'

describe "Que integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/que.rb') }

  context "with que" do
    before do
      module Que
        class Job
          def _run
            run
          end

          def attrs
            {
              job_id: 123,
              queue: 'dfl',
              job_class: self.class.name,
              priority: 100,
              args: ['the floor'],
              run_at: '1-1-1'
            }
          end
        end
      end

      class SuccessJob < Que::Job
        def run
        end
      end

      class FailureJob < Que::Job
        def run
          raise TestError.new('the roof')
        end

        class TestError < StandardError
        end
      end

      load file
      start_agent
    end

    describe :around_perform_resque_plugin do
      let(:transaction) { Appsignal::Transaction.new(1, {}) }
      let(:job) { SuccessJob.new }
      let(:invoked_job) { nil }
      before do
        transaction.stub(:complete! => true)
        Appsignal::Transaction.stub(:current => transaction)
      end

      context "without exception" do
        it "should create a new transaction" do
          Appsignal::Transaction.should_receive(:create).and_return(transaction)
        end

        it "should wrap in a transaction with the correct params" do
          Appsignal.should_receive(:monitor_transaction).with(
            'perform_job.que',
            class:  'SuccessJob',
            method: 'run',
            metadata: {
              id: 123,
              queue: 'dfl',
              priority: 100,
              run_at: '1-1-1',
              attempts: 0
            },
            params: ['the floor']
          )
        end

        it "should close the transaction" do
          transaction.should_receive(:complete!)
        end

        after { job._run }
      end

      context "with exception" do
        let(:job) { FailureJob.new }
        it "should set the exception" do
          transaction.should_receive(:add_exception)
        end

        after do
          begin
            job._run
          rescue FailureJob::TestError
            # Do nothing
          end
        end
      end
    end
  end

  context "without que" do
    before(:all) { Object.send(:remove_const, :Que) }

    specify { expect { ::Que }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
