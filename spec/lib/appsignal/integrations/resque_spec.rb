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
        expect(root_span.attributes["messaging.system"]).to eq("resque")
        expect(root_span.attributes["messaging.operation.name"]).to eq("perform")
        expect(root_span.attributes["messaging.operation.type"]).to eq("process")
        expect(root_span.attributes["messaging.destination.name"]).to eq("default")
        expect(root_span.attributes["appsignal.namespace"]).to eq("background")
        expect(root_span.attributes["appsignal.action_name"]).to eq("ResqueTestJob#perform")
        expect(exception_events).to be_empty
        expect(root_span.attributes).to_not have_key("appsignal.tag.metadata_key")
        expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
        span = event_spans.find { |s| s.name == "perform.resque" }
        expect(span.attributes["messaging.system"]).to eq("resque")
        expect(span.attributes["messaging.operation.name"]).to eq("perform")
        expect(span.attributes["messaging.operation.type"]).to eq("process")
        expect(span.attributes["messaging.destination.name"]).to eq("default")
        expect(span).not_to be_nil
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(scope_of(root_span)).to eq(["appsignal-ruby/resque", Appsignal::VERSION])
        expect(scope_of(span)).to eq(["appsignal-ruby/resque", Appsignal::VERSION])
      end
    end

    describe "with incoming trace context" do
      let(:trace_id_hex) { "0af7651916cd43dd8448eb211c80319c" }
      let(:span_id_hex) { "b7ad6b7169203331" }
      let(:traceparent) { "00-#{trace_id_hex}-#{span_id_hex}-01" }

      def perform
        perform_rescue_job(ResqueTestJob, "traceparent" => traceparent)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        expect(Appsignal).to receive(:stop)
        perform

        # The trace header doesn't leak into the transaction as metadata or tags.
        transaction = last_transaction
        expect(transaction).to_not include_metadata
        expect(transaction).to include_tags("queue" => queue)
        expect(transaction).to_not include_tags("traceparent" => traceparent)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect(Appsignal).to receive(:stop)
        perform

        # The job continues the enqueuer's trace as a child and links back to it.
        expect(root_span.kind).to eq(:consumer)
        expect(root_span.hex_trace_id).to eq(trace_id_hex)
        expect(root_span.parent_span_id.unpack1("H*")).to eq(span_id_hex)
        expect(root_span.links.size).to eq(1)
        link_context = root_span.links.first.span_context
        expect(link_context.hex_trace_id).to eq(trace_id_hex)
        expect(link_context.hex_span_id).to eq(span_id_hex)

        # The trace header doesn't leak into the trace as a tag.
        expect(root_span.attributes).to_not have_key("appsignal.tag.traceparent")
      end

      # The Active Job adapter enqueues a wrapper class with the serialized job
      # data as its only argument, so an Active Job job carries its context one
      # level in, rather than on the Resque job itself.
      context "with an Active Job job carrying the context in its job data" do
        let(:wrapper) { Appsignal::Integrations::ResqueHelpers::ACTIVE_JOB_WRAPPER }
        let(:job_data) do
          {
            "job_class" => "ResqueTestJob",
            "arguments" => [],
            "__otel_headers" => [["traceparent", traceparent]]
          }
        end

        before do
          stub_const(wrapper, Class.new do
            def self.perform(*)
            end
          end)
        end

        def perform
          perform_rescue_job(wrapper, "args" => [job_data])
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          expect(Appsignal).to receive(:stop)
          perform

          expect(last_transaction).to_not include_tags(
            "traceparent" => traceparent
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          expect(Appsignal).to receive(:stop)
          perform

          expect(root_span.kind).to eq(:consumer)
          expect(root_span.hex_trace_id).to eq(trace_id_hex)
          expect(root_span.parent_span_id.unpack1("H*")).to eq(span_id_hex)
          expect(root_span.links.size).to eq(1)
        end
      end

      if DependencyHelper.active_job_present?
        # A round trip through real Active Job and the real Resque adapter. The
        # enqueue writes the trace context onto the job, Active Job serializes
        # it, and the adapter wraps that as the payload's only argument. The
        # payload is captured where Resque would hand it to Redis, so this uses
        # the shape Active Job and Resque really produce, JSON round trip
        # included, without needing a Redis to talk to.
        context "with a job enqueued through real Active Job" do
          before do
            require "active_job"
            ActiveJob::Base.queue_adapter = :resque
            ActiveJob::Base.logger = nil

            stub_const("ResqueRoundTripJob", Class.new(ActiveJob::Base) do
              def perform(*)
              end
            end)
          end

          # Enqueue inside a transaction and perform outside it, because
          # performing while the enqueuing transaction is still open would leave
          # the job sharing it instead of creating its own.
          def enqueue_then_perform
            captured = nil
            allow(::Resque.data_store).to receive(:push_to_queue) do |_queue, encoded|
              captured = ::Resque.decode(encoded)
            end

            set_current_transaction(http_request_transaction)
            ResqueRoundTripJob.perform_later("foo")
            Appsignal::Transaction.complete_current!

            keep_transactions { ::Resque::Job.new(queue, captured).perform }
            captured
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            expect(Appsignal).to receive(:stop)

            payload = enqueue_then_perform

            producer = event_span_for("enqueue.active_job")

            # The shape the integration reads, as Active Job and the Resque
            # adapter really produce it: the adapter's wrapper class, and the
            # serialized job data as its only argument with the trace context
            # inside. The examples that construct this shape by hand to isolate
            # one carrier are only valid as long as this holds.
            expect(payload["class"])
              .to eq(Appsignal::Integrations::ResqueHelpers::ACTIVE_JOB_WRAPPER)
            expect(payload["args"].size).to eq(1)
            expect(payload["args"].first["__otel_headers"]).to eq(
              [["traceparent", "00-#{producer.hex_trace_id}-#{producer.hex_span_id}-01"]]
            )

            consumer = span_exporter.finished_spans.find do |span|
              span.kind == :consumer
            end
            expect(consumer).to_not be_nil
            expect(consumer.hex_trace_id).to eq(producer.hex_trace_id)
            expect(consumer.parent_span_id).to eq(producer.span_id)
          end
        end
      end

      # A job enqueued by a service that instruments Resque but not Active Job
      # has no Active Job carrier to read, so the Resque job's own header is what
      # the trace has to be continued from.
      context "with an Active Job job carrying only a Resque-level context" do
        let(:wrapper) { Appsignal::Integrations::ResqueHelpers::ACTIVE_JOB_WRAPPER }

        before do
          stub_const(wrapper, Class.new do
            def self.perform(*)
            end
          end)
        end

        def perform
          perform_rescue_job(
            wrapper,
            "args" => [{ "job_class" => "ResqueTestJob", "arguments" => [] }],
            "traceparent" => traceparent
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          expect(Appsignal).to receive(:stop)
          perform

          expect(root_span.hex_trace_id).to eq(trace_id_hex)
          expect(root_span.parent_span_id.unpack1("H*")).to eq(span_id_hex)
        end
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
        expect(scope_of(root_span)).to eq(["appsignal-ruby/resque", Appsignal::VERSION])
        expect(scope_of(span)).to eq(["appsignal-ruby/resque", Appsignal::VERSION])
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

      def enqueue
        resque.push("default", item)
      end

      context "with an active transaction" do
        it "in agent mode", :agent_mode do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          expect(enqueue).to eq(:pushed)

          # Records an enqueue event on the transaction, titled after the job;
          # no wire context in agent mode.
          event = transaction.to_h["events"].find { |e| e["name"] == "enqueue.resque" }
          expect(event).to_not be_nil
          expect(event["title"]).to eq("enqueue ResqueTestJob job")
          expect(item).to_not have_key("traceparent")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          expect(enqueue).to eq(:pushed)
          Appsignal::Transaction.complete_current!

          # The enqueue is a producer event span under the active transaction,
          # named after the job being enqueued.
          producer = event_span_for("enqueue.resque")
          expect(producer.name).to eq("enqueue.resque (enqueue ResqueTestJob job)")
          expect(scope_of(producer)).to eq(["appsignal-ruby/resque", Appsignal::VERSION])
          expect(producer.kind).to eq(:producer)
          expect(producer.attributes["messaging.system"]).to eq("resque")
          expect(producer.attributes["messaging.operation.name"]).to eq("enqueue")
          expect(producer.attributes["messaging.operation.type"]).to eq("send")
          expect(producer.attributes["messaging.destination.name"]).to eq("default")
          expect(producer.parent_span_id).to eq(root_span.span_id)

          # The job carries the producer span's trace context, so the job that
          # performs can link back to it.
          expect(item["traceparent"])
            .to eq("00-#{producer.hex_trace_id}-#{producer.hex_span_id}-01")
        end
      end

      context "without an active transaction" do
        it "in agent mode", :agent_mode do
          start_agent

          # A transparent pass-through: the job hash is untouched.
          expect(enqueue).to eq(:pushed)
          expect(item).to_not have_key("traceparent")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          # No transaction to attach the event to, so nothing is emitted and the
          # job hash is untouched.
          expect(enqueue).to eq(:pushed)
          expect(event_spans_for("enqueue.resque")).to be_empty
          expect(item).to_not have_key("traceparent")
        end
      end

      context "when job enqueue events are suppressed" do
        # As happens under Active Job, which records the enqueue itself.
        def enqueue_suppressed(transaction)
          transaction.suppress_job_enqueue_events { enqueue }
        end

        it "in agent mode", :agent_mode do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          expect(enqueue_suppressed(transaction)).to eq(:pushed)

          # The outer integration records the enqueue, so this one doesn't.
          event_names = transaction.to_h["events"].map { |event| event["name"] }
          expect(event_names).to_not include("enqueue.resque")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          expect(enqueue_suppressed(transaction)).to eq(:pushed)
          Appsignal::Transaction.complete_current!

          # No producer span for the suppressed enqueue...
          expect(event_spans_for("enqueue.resque")).to be_empty
          # ...but the trace context is still injected so the job links back.
          expect(item).to have_key("traceparent")
        end
      end

      context "when enqueue instrumentation is disabled" do
        let(:start_agent_args) do
          { :options => { :enable_job_enqueue_instrumentation => false } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          transaction = http_request_transaction
          set_current_transaction(transaction)

          expect(enqueue).to eq(:pushed)

          event_names = transaction.to_h["events"].map { |event| event["name"] }
          expect(event_names).to_not include("enqueue.resque")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          expect(enqueue).to eq(:pushed)
          Appsignal::Transaction.complete_current!

          # No enqueue event means no producer span, so there is nothing for the
          # performing job to link back to and no trace context is written. The
          # job starts its own trace instead of linking to the web request.
          expect(event_spans_for("enqueue.resque")).to be_empty
          expect(item).to_not have_key("traceparent")
        end
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
