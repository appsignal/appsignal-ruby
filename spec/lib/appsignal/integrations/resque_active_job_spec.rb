if DependencyHelper.resque_present? && DependencyHelper.active_job_present?
  require "active_job"

  describe Appsignal::Integrations::ResqueActiveJobPlugin do
    let(:file) { File.expand_path("lib/appsignal/integrations/resque_active_job.rb") }
    let(:args) { "argument" }
    let(:job) { TestActiveJob.new(args) }
    before do
      load file
      start_agent

      class TestActiveJob < ActiveJob::Base
        include Appsignal::Integrations::ResqueActiveJobPlugin

        def perform(_)
        end
      end
    end

    it "wraps it in a transaction with the correct params" do
      expect(Appsignal).to receive(:monitor_single_transaction).with(
        "perform_job.resque",
        :class  => "TestActiveJob",
        :method => "perform",
        :params => ["argument"],
        :metadata => {
          :id    => kind_of(String),
          :queue => "default"
        }
      )
    end

    context "with complex arguments" do
      let(:args) do
        {
          :foo => "Foo",
          :bar => "Bar"
        }
      end

      it "truncates large argument values" do
        expect(Appsignal).to receive(:monitor_single_transaction).with(
          "perform_job.resque",
          :class  => "TestActiveJob",
          :method => "perform",
          :params => [
            :foo => "Foo",
            :bar => "Bar"
          ],
          :metadata => {
            :id    => kind_of(String),
            :queue => "default"
          }
        )
      end

      context "with parameter filtering" do
        before do
          Appsignal.config = project_fixture_config("production")
          Appsignal.config[:filter_parameters] = ["foo"]
        end

        it "filters selected arguments" do
          expect(Appsignal).to receive(:monitor_single_transaction).with(
            "perform_job.resque",
            :class  => "TestActiveJob",
            :method => "perform",
            :params => [
              :foo => "[FILTERED]",
              :bar => "Bar"
            ],
            :metadata => {
              :id    => kind_of(String),
              :queue => "default"
            }
          )
        end
      end
    end

    after { job.perform_now }
  end
end
