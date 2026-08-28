if DependencyHelper.delayed_job_present?
  require "delayed_job"
  require "appsignal/integrations/delayed_job_plugin"
  # Delayed Job ships an in-memory test backend in its own `spec/` dir. Loading
  # it lets us drive the real enqueue/perform lifecycle without a database.
  require "#{Gem::Specification.find_by_name("delayed_job").gem_dir}/spec/delayed/backend/test"

  describe "Delayed Job integration" do
    before do
      Delayed::Worker.backend = Delayed::Backend::Test::Job
      Delayed::Worker.delay_jobs = true
      Delayed::Backend::Test::Job.delete_all

      # Register our plugin exactly once on a fresh lifecycle. Delayed Job
      # registers a plugin's callbacks when it instantiates the plugin (via
      # `setup_lifecycle`); resetting the list and rebuilding per-example keeps
      # the enqueue/perform from being instrumented more than once, whatever the
      # AppSignal hook may have appended to the list.
      Delayed::Worker.plugins.delete(Appsignal::Integrations::DelayedJobPlugin)
      Delayed::Worker.plugins << Appsignal::Integrations::DelayedJobPlugin
      Delayed::Worker.setup_lifecycle

      # The unreadable-payload warning is emitted once per process, so it has to
      # be reset or only the first example to reach it would see it.
      Appsignal::Integrations::DelayedJobPlugin.reset_unreadable_payload_warning!

      stub_const("DelayedTestJob", Class.new do
        def perform
        end
      end)
    end

    # `invoke_job` runs the real `:invoke_job` lifecycle (and re-raises on
    # error). Unlike `Delayed::Worker#run` it doesn't rebuild the lifecycle or
    # swallow the job's exception, so it drives our instrumentation directly.
    def perform_job(job)
      job.invoke_job
    end

    describe "enqueueing a job" do
      context "with an active transaction" do
        it "records an enqueue event titled after the job", :agent_mode do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          Delayed::Job.enqueue(DelayedTestJob.new, :queue => "dj-queue")

          event = transaction.to_h["events"].find { |e| e["name"] == "enqueue.delayed_job" }
          expect(event).to_not be_nil
          expect(event["title"]).to eq("enqueue DelayedTestJob job")
        end

        it "records the enqueue as a producer span", :collector_mode do
          start_collector_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          Delayed::Job.enqueue(DelayedTestJob.new, :queue => "dj-queue")
          Appsignal::Transaction.complete_current!

          # Delayed Job has no envelope to carry trace context, so -- like
          # OpenTelemetry's own instrumentation -- nothing is injected; the
          # producer span is not linked to the later perform.
          producer = event_span_for("enqueue.delayed_job")
          expect(producer.name).to eq("enqueue.delayed_job (enqueue DelayedTestJob job)")
          expect(scope_of(producer)).to eq(["appsignal-ruby/delayed_job", Appsignal::VERSION])
          expect(producer.kind).to eq(:producer)
          expect(producer.attributes["messaging.system"]).to eq("delayed_job")
          expect(producer.attributes["messaging.operation.name"]).to eq("enqueue")
          expect(producer.attributes["messaging.operation.type"]).to eq("send")
          expect(producer.attributes["messaging.destination.name"]).to eq("dj-queue")
          expect(producer.parent_span_id).to eq(root_span.span_id)
        end
      end

      context "when enqueue instrumentation is disabled" do
        let(:start_agent_args) do
          { :options => { :enable_job_enqueue_instrumentation => false } }
        end

        it "records no enqueue event but still enqueues the job", :agent_mode do
          start_agent(**start_agent_args)
          transaction = http_request_transaction
          set_current_transaction(transaction)

          expect { Delayed::Job.enqueue(DelayedTestJob.new) }
            .to change { Delayed::Backend::Test::Job.count }.by(1)

          event_names = transaction.to_h["events"].map { |event| event["name"] }
          expect(event_names).to_not include("enqueue.delayed_job")
        end

        it "emits no enqueue span but still enqueues the job", :collector_mode do
          start_collector_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          expect { Delayed::Job.enqueue(DelayedTestJob.new) }
            .to change { Delayed::Backend::Test::Job.count }.by(1)
          Appsignal::Transaction.complete_current!

          expect(event_spans_for("enqueue.delayed_job")).to be_empty
        end
      end

      context "without an active transaction" do
        it "is a transparent pass-through", :agent_mode do
          start_agent

          expect { Delayed::Job.enqueue(DelayedTestJob.new) }
            .to change { Delayed::Backend::Test::Job.count }.by(1)
        end

        it "emits no enqueue span", :collector_mode do
          start_collector_agent

          Delayed::Job.enqueue(DelayedTestJob.new)

          # Event span names lead with the event category, so derive the
          # categories from the event spans and check none is the enqueue event.
          categories = event_spans.map { |s| event_category(s) }
          expect(categories).to_not include("enqueue.delayed_job")
        end
      end

      if DependencyHelper.active_job_delayed_job_adapter_present?
        context "when wrapped by Active Job" do
          # Active Job records its own `enqueue.active_job` event and suppresses
          # the backend's, so no duplicate is recorded here.
          before do
            require "active_job"
            ActiveJob::Base.queue_adapter = :delayed_job
            ActiveJob::Base.logger = nil

            stub_const("DelayedActiveJob", Class.new(ActiveJob::Base) do
              def perform(*)
              end
            end)
          end

          it "does not record a second enqueue event", :agent_mode do
            start_agent
            transaction = http_request_transaction
            set_current_transaction(transaction)

            DelayedActiveJob.perform_later

            event_names = transaction.to_h["events"].map { |e| e["name"] }
            expect(event_names).to include("enqueue.active_job")
            expect(event_names).to_not include("enqueue.delayed_job")
          end
        end
      end

      context "with a custom appsignal_name" do
        before do
          stub_const("DelayedNamedJob", Class.new do
            def perform
            end

            def appsignal_name
              "CustomName#perform"
            end
          end)
        end

        it "titles the enqueue event with the custom name", :agent_mode do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          Delayed::Job.enqueue(DelayedNamedJob.new)

          event = transaction.to_h["events"].find { |e| e["name"] == "enqueue.delayed_job" }
          expect(event["title"]).to eq("enqueue CustomName#perform job")
        end
      end
    end

    describe "performing a job" do
      context "with a normal job" do
        it "wraps it in a background_job transaction", :agent_mode do
          start_agent
          job = Delayed::Job.enqueue(DelayedTestJob.new, :queue => "dj-queue")

          keep_transactions { perform_job(job) }

          transaction = last_transaction
          expect(transaction).to have_namespace("background_job")
          expect(transaction).to have_action("DelayedTestJob#perform")
          expect(transaction).to_not have_error
          expect(transaction).to include_event(:name => "perform_job.delayed_job")
          expect(transaction).to include_tags("attempts" => 0, "priority" => 0)
        end

        it "wraps it in a consumer span", :collector_mode do
          start_collector_agent
          job = Delayed::Job.enqueue(DelayedTestJob.new, :queue => "dj-queue")

          perform_job(job)
          Appsignal::Transaction.complete_current!

          expect(root_span.kind).to eq(:consumer)
          expect(root_span.attributes["messaging.system"]).to eq("delayed_job")
          expect(root_span.attributes["messaging.operation.name"]).to eq("perform")
          expect(root_span.attributes["messaging.operation.type"]).to eq("process")
          expect(root_span.attributes["messaging.destination.name"]).to eq("dj-queue")
          expect(root_span.attributes["appsignal.action_name"]).to eq("DelayedTestJob#perform")
          expect(root_span.attributes["appsignal.namespace"]).to eq("background")
          expect(event_spans.map(&:name)).to include("perform_job.delayed_job")
          perform_span = event_spans.find { |s| s.name == "perform_job.delayed_job" }
          expect(perform_span.attributes["messaging.system"]).to eq("delayed_job")
          expect(perform_span.attributes["messaging.operation.name"]).to eq("perform")
          expect(perform_span.attributes["messaging.operation.type"]).to eq("process")
          expect(perform_span.attributes["messaging.destination.name"]).to eq("dj-queue")
          expect(scope_of(root_span)).to eq(["appsignal-ruby/delayed_job", Appsignal::VERSION])
          expect(scope_of(perform_span)).to eq(["appsignal-ruby/delayed_job", Appsignal::VERSION])
        end
      end

      context "with a job that raises" do
        before do
          stub_const("DelayedErrorJob", Class.new do
            def perform
              raise ExampleException, "uh oh"
            end
          end)
        end

        it "records the error on the transaction", :agent_mode do
          start_agent
          job = Delayed::Job.enqueue(DelayedErrorJob.new)

          keep_transactions do
            expect { perform_job(job) }.to raise_error(ExampleException, "uh oh")
          end

          transaction = last_transaction
          expect(transaction).to have_namespace("background_job")
          expect(transaction).to have_action("DelayedErrorJob#perform")
          expect(transaction).to have_error("ExampleException", "uh oh")
        end

        it "records the error on the consumer span", :collector_mode do
          start_collector_agent
          job = Delayed::Job.enqueue(DelayedErrorJob.new)

          expect { perform_job(job) }.to raise_error(ExampleException, "uh oh")
          Appsignal::Transaction.complete_current!

          expect(root_span.kind).to eq(:consumer)
          event = root_span.events.find { |e| e.name == "exception" }
          expect(event.attributes["exception.type"]).to eq("ExampleException")
          expect(event.attributes["exception.message"]).to eq("uh oh")
        end
      end

      if DependencyHelper.active_job_delayed_job_adapter_present?
        # A full round trip through real Active Job and the real Delayed Job
        # adapter. The enqueue writes the trace context onto the job, Active Job
        # serializes it, Delayed Job stores that in the handler, and the perform
        # reads it back. No part of the job's shape is written by hand here, so
        # this fails if any assumption about that shape is wrong.
        context "with a job enqueued through real Active Job" do
          before do
            require "active_job"
            ActiveJob::Base.queue_adapter = :delayed_job
            ActiveJob::Base.logger = nil

            stub_const("DelayedRoundTripJob", Class.new(ActiveJob::Base) do
              def perform(*)
              end
            end)
          end

          # Enqueue inside a transaction and perform outside it, because
          # performing while the enqueuing transaction is still open would leave
          # the job sharing it instead of creating its own.
          def enqueue_then_perform
            set_current_transaction(http_request_transaction)
            DelayedRoundTripJob.perform_later("foo")
            Appsignal::Transaction.complete_current!

            perform_job(Delayed::Backend::Test::Job.all.last)
          end

          it "in collector mode", :collector_mode do
            start_collector_agent

            enqueue_then_perform

            producer = event_span_for("enqueue.active_job")
            consumer = span_exporter.finished_spans.find do |span|
              span.kind == :consumer
            end
            expect(consumer).to_not be_nil
            expect(consumer.attributes["appsignal.action_name"])
              .to eq("DelayedRoundTripJob#perform")
            # The job continues the enqueuer's trace as a child of the producer
            # span, and links back to it.
            expect(consumer.hex_trace_id).to eq(producer.hex_trace_id)
            expect(consumer.parent_span_id).to eq(producer.span_id)
            expect(consumer.links.map { |link| link.span_context.hex_span_id })
              .to eq([producer.hex_span_id])
          end
        end
      end

      # Delayed Job has no carrier of its own, so an Active Job job is the only
      # kind whose trace can be continued here. The adapter wraps the serialized
      # job data in an object that exposes it as `job_data`.
      context "with an Active Job job carrying incoming trace context" do
        let(:trace_id_hex) { "0af7651916cd43dd8448eb211c80319c" }
        let(:span_id_hex) { "b7ad6b7169203331" }
        let(:traceparent) { "00-#{trace_id_hex}-#{span_id_hex}-01" }
        let(:job_data) do
          {
            "job_class" => "DelayedActiveJob",
            "arguments" => [],
            "__otel_headers" => [["traceparent", traceparent]]
          }
        end
        let(:job) do
          wrapper = Struct.new(:job_data) do
            def perform
            end
          end
          Delayed::Job.enqueue(wrapper.new(job_data))
        end

        it "in agent mode", :agent_mode do
          start_agent

          keep_transactions { perform_job(job) }

          transaction = last_transaction
          expect(transaction).to be_completed
          expect(transaction).to have_action("DelayedActiveJob#perform")
          # The trace header doesn't leak into the transaction as a tag.
          expect(transaction).to_not include_tags("traceparent" => traceparent)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          perform_job(job)

          expect(root_span.kind).to eq(:consumer)
          expect(root_span.hex_trace_id).to eq(trace_id_hex)
          expect(root_span.parent_span_id.unpack1("H*")).to eq(span_id_hex)
          expect(root_span.links.size).to eq(1)
        end
      end

      # A job from an Active Job bulk enqueue carries a marker alongside its
      # trace context, because every job in the batch shares one producer span.
      context "with an Active Job job from a bulk enqueue" do
        let(:trace_id_hex) { "0af7651916cd43dd8448eb211c80319c" }
        let(:span_id_hex) { "b7ad6b7169203331" }
        let(:traceparent) { "00-#{trace_id_hex}-#{span_id_hex}-01" }
        let(:job) do
          wrapper = Struct.new(:job_data) do
            def perform
            end
          end
          Delayed::Job.enqueue(
            wrapper.new(
              {
                "job_class" => "DelayedActiveJob",
                "arguments" => [],
                "__otel_headers" => [
                  ["traceparent", traceparent],
                  [Appsignal::OpenTelemetry::ACTIVE_JOB_BATCH_HEADER, "1"]
                ]
              }
            )
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          perform_job(job)

          # Every job in the batch shares the one producer span, so the job
          # only links back to it. It gets its own trace instead of hanging the
          # whole batch off that span.
          expect(root_span.kind).to eq(:consumer)
          expect(root_span.parent_span_id).to eq(::OpenTelemetry::Trace::INVALID_SPAN_ID)
          expect(root_span.hex_trace_id).to_not eq(trace_id_hex)
          expect(root_span.links.size).to eq(1)
          expect(root_span.links.first.span_context.hex_trace_id).to eq(trace_id_hex)
        end
      end

      # What a deploy that removes a job class leaves behind: jobs whose stored
      # handler names a class that is gone. Created straight through the backend,
      # because `Delayed::Job.enqueue` stores the live object next to the handler
      # and Delayed Job then never parses the handler at all.
      context "with a job whose payload cannot be deserialized" do
        let(:job) do
          Delayed::Backend::Test::Job.create(
            :handler => "--- !ruby/object:TotallyMissingJobClass {}\n"
          )
        end

        it "reports the job with its deserialization error", :agent_mode do
          start_agent

          keep_transactions do
            expect { perform_job(job) }.to raise_error(
              Delayed::DeserializationError, /TotallyMissingJobClass/
            )
          end

          transaction = last_transaction
          expect(transaction).to be_completed
          expect(transaction).to have_namespace("background_job")
          expect(transaction).to have_error(
            "Delayed::DeserializationError", /TotallyMissingJobClass/
          )
          # Delayed Job reads the class name out of the raw handler when the
          # payload will not load, so the job is still named after its class.
          expect(transaction).to have_action("TotallyMissingJobClass#perform")
          expect(transaction).to include_tags("attempts" => 0, "priority" => 0)
        end

        it "records the error on the consumer span", :collector_mode do
          start_collector_agent

          expect { perform_job(job) }.to raise_error(
            Delayed::DeserializationError, /TotallyMissingJobClass/
          )

          # No `complete_current!` call here, on purpose. A span only reaches the
          # exporter once it has ended, so having a `root_span` at all is what
          # proves the integration completed the transaction itself.
          expect(root_span.kind).to eq(:consumer)
          expect(root_span.attributes["appsignal.action_name"])
            .to eq("TotallyMissingJobClass#perform")
          expect(root_span.attributes).to_not have_key("appsignal.ignore_subtrace")
          event = root_span.events.find { |e| e.name == "exception" }
          expect(event.attributes["exception.type"])
            .to eq("Delayed::DeserializationError")
          expect(event.attributes["exception.message"])
            .to match(/TotallyMissingJobClass/)
        end

        # Untagged: the warning is logged from the same code in both modes, so
        # there is nothing mode-specific to assert about it.
        it "logs that the payload could not be read, once per process" do
          start_agent
          other_job = Delayed::Backend::Test::Job.create(:handler => job.handler)

          logs = capture_logs do
            keep_transactions do
              [job, other_job].each do |unreadable_job|
                expect { perform_job(unreadable_job) }
                  .to raise_error(Delayed::DeserializationError)
              end
            end
          end

          expect(logs).to contains_log(
            :warn, "Unable to read a Delayed Job job's payload"
          )
          # Both jobs failed, but a deploy that removes a job class can leave
          # very many of them, so the warning is only worth logging once.
          expect(logs.scan("Unable to read a Delayed Job").count).to eq(1)
        end

        # A handler that defeats the class-name expression Delayed Job falls back
        # to, so the job's own class cannot be named.
        context "when the handler cannot be parsed for a class name either" do
          let(:job) { Delayed::Backend::Test::Job.create(:handler => "--- {\n") }

          it "names the job after Delayed Job", :agent_mode do
            start_agent

            keep_transactions do
              expect { perform_job(job) }
                .to raise_error(Delayed::DeserializationError)
            end

            transaction = last_transaction
            expect(transaction).to be_completed
            expect(transaction).to have_error("Delayed::DeserializationError", /./)
            # Named after Delayed Job itself, so the failure is reported under a
            # name that can be found rather than under none.
            expect(transaction).to have_action("Delayed::Job#perform")
            expect(transaction).to include_tags("attempts" => 0, "priority" => 0)
          end

          it "names the consumer span after Delayed Job", :collector_mode do
            start_collector_agent

            expect { perform_job(job) }
              .to raise_error(Delayed::DeserializationError)

            expect(root_span.kind).to eq(:consumer)
            expect(root_span.attributes["appsignal.action_name"])
              .to eq("Delayed::Job#perform")
            # An exported span is not necessarily a reported one: the collector
            # drops a subtrace flagged with this attribute. Naming the span is
            # what keeps the failure reported.
            expect(root_span.attributes).to_not have_key("appsignal.ignore_subtrace")
            event = root_span.events.find { |e| e.name == "exception" }
            expect(event.attributes["exception.type"])
              .to eq("Delayed::DeserializationError")
          end
        end
      end

      context "with a custom appsignal_name" do
        before do
          stub_const("DelayedNamedJob", Class.new do
            def perform
            end

            def appsignal_name
              "CustomName#perform"
            end
          end)
        end

        it "uses the custom name as the action", :agent_mode do
          start_agent
          job = Delayed::Job.enqueue(DelayedNamedJob.new)

          keep_transactions { perform_job(job) }

          expect(last_transaction).to have_action("CustomName#perform")
        end
      end

      if DependencyHelper.active_job_delayed_job_adapter_present?
        context "when wrapped by Active Job" do
          before do
            require "active_job"
            ActiveJob::Base.queue_adapter = :delayed_job
            ActiveJob::Base.logger = nil

            stub_const("DelayedActiveJob", Class.new(ActiveJob::Base) do
              def perform(*)
              end
            end)
          end

          it "uses the Active Job class as the action", :agent_mode do
            start_agent

            keep_transactions do
              DelayedActiveJob.perform_later("arg")
              perform_job(Delayed::Backend::Test::Job.all.last)
            end

            transaction = last_transaction
            expect(transaction).to have_namespace("background_job")
            expect(transaction).to have_action("DelayedActiveJob#perform")
            expect(transaction).to include_params(["arg"])
          end
        end
      end
    end

    describe ".extract_value" do
      let(:plugin) { Appsignal::Integrations::DelayedJobPlugin }

      before { start_agent }

      context "for a hash" do
        let(:hash) { { :key => "value", :bool_false => false } }

        it "reads an existing key" do
          expect(plugin.extract_value(hash, :key)).to eq("value")
        end

        it "reads a false value" do
          expect(plugin.extract_value(hash, :bool_false)).to be(false)
        end

        it "returns the default for a missing key" do
          expect(plugin.extract_value(hash, :nope, 1)).to eq(1)
        end
      end

      context "for an object" do
        let(:object) { double(:existing_method => "value") }

        it "reads an existing method" do
          expect(plugin.extract_value(object, :existing_method)).to eq("value")
        end

        it "returns the default for a missing method" do
          expect(plugin.extract_value(object, :nope, 1)).to eq(1)
        end
      end

      it "converts the value to a string when asked" do
        object = double(:existing_method => 1)
        expect(plugin.extract_value(object, :existing_method, nil, true)).to eq("1")
      end
    end
  end
end
