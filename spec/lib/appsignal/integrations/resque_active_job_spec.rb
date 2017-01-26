if DependencyHelper.resque_present? && DependencyHelper.active_job_present?
  describe "Resque ActiveJob integration" do
    let(:file) { File.expand_path("lib/appsignal/integrations/resque_active_job.rb") }

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
        before    { allow(SecureRandom).to receive(:uuid).and_return(123) }
        let(:job) { TestActiveJob.new("moo") }

        it "should wrap in a transaction with the correct params" do
          expect(Appsignal).to receive(:monitor_single_transaction).with(
            "perform_job.resque",
            :class  => "TestActiveJob",
            :method => "perform",
            :params => ["moo"],
            :metadata => {
              :id    => 123,
              :queue => "default"
            }
          )
        end
        after { job.perform_now }
      end
    end
  end
end
