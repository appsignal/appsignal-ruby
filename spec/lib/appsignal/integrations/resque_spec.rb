require 'spec_helper'

if resque_present?
  describe "Resque integration" do
    let(:file) { File.expand_path('lib/appsignal/integrations/resque.rb') }

    context "with resque" do
      before do
        load file
        start_agent

        class TestJob
          extend Appsignal::Integrations::ResquePlugin

          def self.perform
          end
        end

        class BrokenTestJob
          extend Appsignal::Integrations::ResquePlugin

          def self.perform
            raise VerySpecificError.new('broken')
          end
        end
      end

      describe :around_perform_resque_plugin do
        let(:transaction) { Appsignal::Transaction.new('1', 'background', {}, {}) }
        let(:job) { ::Resque::Job.new('default', {'class' => 'TestJob'}) }
        before do
          transaction.stub(:complete => true)
          Appsignal::Transaction.stub(:current => transaction)
          Appsignal.should_receive(:stop)
        end

        context "without exception" do
          it "should create a new transaction" do
            Appsignal::Transaction.should_receive(:create).and_return(transaction)
          end

          it "should wrap in a transaction with the correct params" do
            Appsignal.should_receive(:monitor_transaction).with(
              'perform_job.resque',
              :class => 'TestJob',
              :method => 'perform'
            )
          end

          it "should close the transaction" do
            transaction.should_receive(:complete)
          end

          after { job.perform  }
        end

        context "with exception" do
          let(:job) { ::Resque::Job.new('default', {'class' => 'BrokenTestJob'}) }

          it "should set the exception" do
            Appsignal::Transaction.any_instance.should_receive(:set_error)
          end

          after do
            begin
              job.perform
            rescue VerySpecificError
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
end
