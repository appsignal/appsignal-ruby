require "appsignal/integrations/resque"

if DependencyHelper.resque_present?
  describe Appsignal::Integrations::ResqueIntegration do
    def perform_rescue_job(klass, options = {})
      payload = { "class" => klass.to_s }.merge(options)
      job = ::Resque::Job.new(queue, payload)
      keep_transactions { job.perform }
    end

    let(:queue) { "default" }
    let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
    let(:options) { {} }
    before do
      start_agent(:options => options)

      stub_const("ResqueTestJob", Class.new do
        def self.perform(*_args)
        end
      end)

      stub_const("ResqueErrorTestJob", Class.new do
        def self.perform
          raise "resque job error"
        end
      end)

      expect(Appsignal).to receive(:stop) # Resque calls stop after every job
    end
    around do |example|
      keep_transactions { example.run }
    end

    it "tracks a transaction on perform" do
      perform_rescue_job(ResqueTestJob)

      transaction = last_transaction
      expect(transaction).to have_id
      expect(transaction).to have_namespace(namespace)
      expect(transaction).to have_action("ResqueTestJob#perform")
      expect(transaction).to_not have_error
      expect(transaction).to_not include_metadata
      expect(transaction).to_not include_breadcrumbs
      expect(transaction).to include_tags("queue" => queue)
      expect(transaction).to include_event("name" => "perform.resque")
    end

    context "with error" do
      it "tracks the error on the transaction" do
        expect do
          perform_rescue_job(ResqueErrorTestJob)
        end.to raise_error(RuntimeError, "resque job error")

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(namespace)
        expect(transaction).to have_action("ResqueErrorTestJob#perform")
        expect(transaction).to have_error("RuntimeError", "resque job error")
        expect(transaction).to_not include_metadata
        expect(transaction).to_not include_breadcrumbs
        expect(transaction).to include_tags("queue" => queue)
        expect(transaction).to include_event("name" => "perform.resque")
      end
    end

    context "with arguments" do
      let(:options) { { :filter_parameters => ["foo"] } }

      it "filters out configured arguments" do
        perform_rescue_job(
          ResqueTestJob,
          "args" => [
            "foo",
            {
              "foo" => "secret",
              "bar" => "Bar",
              "baz" => { "1" => "foo" }
            }
          ]
        )

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(namespace)
        expect(transaction).to have_action("ResqueTestJob#perform")
        expect(transaction).to_not have_error
        expect(transaction).to_not include_metadata
        expect(transaction).to_not include_breadcrumbs
        expect(transaction).to include_tags("queue" => queue)
        expect(transaction).to include_event("name" => "perform.resque")
        expect(transaction).to include_params(
          [
            "foo",
            {
              "foo" => "[FILTERED]",
              "bar" => "Bar",
              "baz" => { "1" => "foo" }
            }
          ]
        )
      end
    end

    context "with active job" do
      before do
        module ActiveJobMock
          module QueueAdapters
            module ResqueAdapter
              module JobWrapper
                class << self
                  def perform(job_data)
                    # Basic ActiveJob stub for this test.
                    # I haven't found a way to run Resque in a testing mode.
                    Appsignal.set_action(job_data["job_class"])
                  end
                end
              end
            end
          end
        end

        stub_const "ActiveJob", ActiveJobMock
      end
      after { Object.send(:remove_const, :ActiveJobMock) }

      it "does not set arguments but lets the ActiveJob integration handle it" do
        perform_rescue_job(
          ResqueTestJob,
          "class" => "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
          "args" => [
            {
              "job_class" => "ResqueTestJobByActiveJob#perform",
              "arguments" => ["an argument", "second argument"]
            }
          ]
        )

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(namespace)
        expect(transaction).to have_action("ResqueTestJobByActiveJob#perform")
        expect(transaction).to_not have_error
        expect(transaction).to_not include_metadata
        expect(transaction).to_not include_breadcrumbs
        expect(transaction).to include_tags("queue" => queue)
        expect(transaction).to include_event("name" => "perform.resque")
        expect(transaction).to_not include_params
      end
    end
  end
end
