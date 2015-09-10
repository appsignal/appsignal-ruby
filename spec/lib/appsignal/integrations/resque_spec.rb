require 'spec_helper'

describe "Resque integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/resque.rb') }

  context "with resque" do
    before do
      module Resque

        def self.before_first_fork
        end

        def self.after_fork
        end

        class Job
        end

        class TestError < StandardError
        end
      end

      load file
      start_agent
    end

    describe :around_perform_resque_plugin do
      let(:transaction) { background_job_transaction }
      let(:job) { Resque::Job }
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
            'perform_job.resque',
            :class => 'Resque::Job',
            :method => 'perform'
          )
        end

        it "should close the transaction" do
          Appsignal::Transaction.should_receive(:complete_current!)
        end

        after { job.around_perform_resque_plugin { invoked_job }  }
      end

      context "with exception" do
        it "should set the exception" do
          Appsignal::Transaction.any_instance.should_receive(:set_error)
        end

        after do
          begin
            job.around_perform_resque_plugin { raise(Resque::TestError.new('the roof')) }
          rescue Resque::TestError
            # Do nothing
          end
        end
      end
    end
  end

  context "without resque" do
    before(:all) { Object.send(:remove_const, :Resque) }

    specify { expect { ::Resque }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
