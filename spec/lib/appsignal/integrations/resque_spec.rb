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
        stub_const("ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper", Class.new do
          class << self
            def perform(job_data)
              # Basic ActiveJob stub for this test.
              # I haven't found a way to run Resque in a testing mode.
              Appsignal.set_action(job_data["job_class"])
            end
          end
        end)
      end

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

  describe Appsignal::Integrations::ResquePushIntegration do
    # A stand-in for the `Resque` singleton with the integration prepended.
    # Its `push` records the pushed item so we can inspect what was written.
    let(:resque) do
      Class.new do
        attr_reader :pushed

        def push(queue, item)
          @pushed = [queue, item]
          :pushed
        end

        prepend Appsignal::Integrations::ResquePushIntegration
      end.new
    end
    let(:item) { { "class" => "ResqueTestJob", "args" => [] } }

    before { start_agent }
    around { |example| keep_transactions { example.run } }

    def enqueue
      resque.push("default", item)
    end

    context "with an active transaction" do
      it "records an enqueue event and leaves the job untouched" do
        transaction = http_request_transaction
        set_current_transaction(transaction)

        expect(enqueue).to eq(:pushed)

        event_names = transaction.to_h["events"].map { |event| event["name"] }
        expect(event_names).to include("enqueue.resque")
        expect(item).to eq("class" => "ResqueTestJob", "args" => [])
      end
    end

    context "without an active transaction" do
      it "is a transparent pass-through" do
        expect(enqueue).to eq(:pushed)
        expect(item).to eq("class" => "ResqueTestJob", "args" => [])
      end
    end

    context "when job enqueue events are suppressed" do
      # As happens under Active Job, which records the enqueue itself.
      it "passes through without recording the enqueue" do
        transaction = http_request_transaction
        set_current_transaction(transaction)

        result = transaction.suppress_job_enqueue_events { enqueue }
        expect(result).to eq(:pushed)

        # The outer integration records the enqueue, so this one doesn't.
        event_names = transaction.to_h["events"].map { |event| event["name"] }
        expect(event_names).to_not include("enqueue.resque")
      end
    end
  end
end
