require 'spec_helper'

if resque_present? && active_job_present?
  describe "Resque ActiveJob integration" do
    let(:file) { File.expand_path('lib/appsignal/integrations/resque_active_job.rb') }

    context "with Resque and ActiveJob" do
      before do
        load file
        start_agent

        class TestActiveJob < ActiveJob::Base
          include Appsignal::Integrations::ResqueActiveJobPlugin

          def perform(param)
          end
        end
      end

      describe :around_perform_plugin do
        before    { SecureRandom.stub(:uuid => 123) }
        let(:job) { TestActiveJob.new('moo') }

        it "should wrap in a transaction with the correct params" do
          Appsignal.should_receive(:monitor_single_transaction).with(
            'perform_job.resque',
            :class  => 'TestActiveJob',
            :method => 'perform',
            :params => ['moo'],
            :metadata => {
              :id    => 123,
              :queue => 'default'
            }
          )
        end
        after { job.perform_now }
      end
    end

    context "without ActiveJob" do
      before(:all) { Object.send(:remove_const, :ActiveJob) }

      specify { expect { ::ActiveJob }.to raise_error(NameError) }
      specify { expect { load file }.to_not raise_error }
    end

    context "without Resque" do
      before(:all) { Object.send(:remove_const, :Resque) }

      specify { expect { ::Resque }.to raise_error(NameError) }
      specify { expect { load file }.to_not raise_error }
    end
  end
end
