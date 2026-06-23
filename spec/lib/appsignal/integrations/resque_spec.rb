require "appsignal/integrations/resque"

if DependencyHelper.resque_present?
  describe Appsignal::Integrations::ResqueIntegration do
    let(:queue) { "default" }
    let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
    let(:options) { {} }
    let(:start_agent_args) { { :options => options } }

    before do
      stub_const("ResqueTestJob", Class.new do
        def self.perform(*_args)
        end
      end)

      stub_const("ResqueErrorTestJob", Class.new do
        def self.perform
          raise "resque job error"
        end
      end)
    end

    def perform_rescue_job(klass, job_options = {})
      payload = { "class" => klass.to_s }.merge(job_options)
      job = ::Resque::Job.new(queue, payload)
      keep_transactions { job.perform }
    end

    describe "tracks a transaction on perform" do
      def perform
        perform_rescue_job(ResqueTestJob)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        expect(Appsignal).to receive(:stop)
        perform

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

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect(Appsignal).to receive(:stop)
        perform

        expect(root_span.kind).to eq(:consumer)
        expect(root_span.attributes["appsignal.namespace"]).to eq("background")
        expect(root_span.attributes["appsignal.action_name"]).to eq("ResqueTestJob#perform")
        expect(exception_events).to be_empty
        expect(root_span.attributes).to_not have_key("appsignal.tag.metadata_key")
        expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
        span = event_spans.find { |s| s.name == "perform.resque" }
        expect(span).not_to be_nil
        expect(span.parent_span_id).to eq(root_span.span_id)
      end
    end

    describe "tracks the error on the transaction" do
      def perform
        expect do
          perform_rescue_job(ResqueErrorTestJob)
        end.to raise_error(RuntimeError, "resque job error")
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        expect(Appsignal).to receive(:stop)
        perform

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

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect(Appsignal).to receive(:stop)
        perform

        expect(root_span.kind).to eq(:consumer)
        expect(root_span.attributes["appsignal.namespace"]).to eq("background")
        expect(root_span.attributes["appsignal.action_name"]).to eq("ResqueErrorTestJob#perform")
        event = root_span.events.find { |e| e.name == "exception" }
        expect(event).not_to be_nil
        expect(event.attributes["exception.type"]).to eq("RuntimeError")
        expect(event.attributes["exception.message"]).to eq("resque job error")
        expect(event.attributes["exception.stacktrace"]).to be_a(String)
        expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
        expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
        span = event_spans.find { |s| s.name == "perform.resque" }
        expect(span).not_to be_nil
        expect(span.parent_span_id).to eq(root_span.span_id)
      end
    end

    describe "filters out configured arguments" do
      let(:options) { { :filter_parameters => ["foo"] } }

      def perform
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
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        expect(Appsignal).to receive(:stop)
        perform

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

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect(Appsignal).to receive(:stop)
        perform

        expect(root_span.attributes["appsignal.namespace"]).to eq("background")
        expect(root_span.attributes["appsignal.action_name"]).to eq("ResqueTestJob#perform")
        expect(exception_events).to be_empty
        expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
        expect(event_spans.map(&:name)).to include("perform.resque")
        params = JSON.parse(root_span.attributes["appsignal.function.parameters"])
        expect(params).to eq(
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

    describe "does not set arguments for ActiveJob" do
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

      def perform
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
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        expect(Appsignal).to receive(:stop)
        perform

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

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect(Appsignal).to receive(:stop)
        perform

        expect(root_span.attributes["appsignal.namespace"]).to eq("background")
        expect(root_span.attributes["appsignal.action_name"])
          .to eq("ResqueTestJobByActiveJob#perform")
        expect(exception_events).to be_empty
        expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
        expect(event_spans.map(&:name)).to include("perform.resque")
        expect(root_span.attributes).to_not have_key("appsignal.function.parameters")
      end
    end
  end
end
