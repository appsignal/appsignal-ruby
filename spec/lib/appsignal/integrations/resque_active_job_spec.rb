if DependencyHelper.active_job_present?
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

    def perform
      keep_transactions do
        job.perform_now
      end
    end

    context "without error" do
      it "creates a new transaction" do
        expect { perform }.to change { created_transactions.length }.by(1)

        expect(last_transaction.to_h).to include(
          "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
          "action" => "TestActiveJob#perform",
          "error" => nil,
          "events" => [
            hash_including(
              "name" => "perform_job.resque",
              "title" => "",
              "body" => "",
              "body_format" => Appsignal::EventFormatter::DEFAULT,
              "count" => 1,
              "duration" => kind_of(Float)
            )
          ],
          "sample_data" => hash_including(
            "params" => ["argument"],
            "metadata" => {
              "id" => kind_of(String),
              "queue" => "default"
            }
          )
        )
      end
    end

    context "with error" do
      let(:job) do
        class BrokenTestActiveJob < ActiveJob::Base
          include Appsignal::Integrations::ResqueActiveJobPlugin

          def perform(_)
            raise ExampleException, "my error message"
          end
        end

        BrokenTestActiveJob.new(args)
      end

      it "creates a new transaction with an error" do
        expect do
          expect { perform }.to raise_error(ExampleException, "my error message")
        end.to change { created_transactions.length }.by(1)

        expect(last_transaction.to_h).to include(
          "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
          "action" => "BrokenTestActiveJob#perform",
          "error" => {
            "name" => "ExampleException",
            "message" => "my error message",
            "backtrace" => kind_of(String)
          },
          "sample_data" => hash_including(
            "params" => ["argument"],
            "metadata" => {
              "id" => kind_of(String),
              "queue" => "default"
            }
          )
        )
      end
    end

    context "with complex arguments" do
      context "with too long values" do
        let(:args) do
          {
            :foo => "Foo",
            :bar => "a" * 2001
          }
        end

        it "truncates large argument values" do
          perform
          expect(last_transaction.to_h).to include(
            "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
            "action" => "TestActiveJob#perform",
            "error" => nil,
            "sample_data" => hash_including(
              "params" => ["foo" => "Foo", "bar" => "#{"a" * 2000}..."],
              "metadata" => {
                "id" => kind_of(String),
                "queue" => "default"
              }
            )
          )
        end
      end

      context "with parameter filtering" do
        let(:args) do
          {
            :foo => "Foo",
            :bar => "Bar"
          }
        end
        before { Appsignal.config[:filter_parameters] = ["foo"] }

        it "filters selected arguments" do
          perform
          expect(last_transaction.to_h).to include(
            "namespace" => Appsignal::Transaction::BACKGROUND_JOB,
            "action" => "TestActiveJob#perform",
            "error" => nil,
            "sample_data" => hash_including(
              "params" => ["foo" => "[FILTERED]", "bar" => "Bar"],
              "metadata" => {
                "id" => kind_of(String),
                "queue" => "default"
              }
            )
          )
        end
      end
    end
  end
end
