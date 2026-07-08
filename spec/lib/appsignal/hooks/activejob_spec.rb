if DependencyHelper.active_job_present?
  require "active_job"
  require "action_mailer"

  describe Appsignal::Hooks::ActiveJobHook do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      context "when ActiveJob constant is found" do
        before { stub_const "ActiveJob", Class.new }

        it { is_expected.to be_truthy }
      end

      context "when ActiveJob constant is not found" do
        before { hide_const "ActiveJob" }

        it { is_expected.to be_falsy }
      end
    end

    describe "#install" do
      it "extends ActiveJob::Base with the AppSignal ActiveJob plugin" do
        start_agent

        path, _line_number = ActiveJob::Base.method(:execute).source_location
        expect(path).to end_with("/lib/appsignal/hooks/active_job.rb")
      end
    end
  end

  describe Appsignal::Hooks::ActiveJobHook::ActiveJobClassInstrumentation do
    include ActiveJobHelpers

    let(:time) { Time.parse("2001-01-01 10:00:00UTC") }
    let(:namespace) { Appsignal::Transaction::BACKGROUND_JOB }
    let(:queue) { "default" }
    let(:parameterized_given_args) do
      {
        :foo => "Foo",
        "bar" => "Bar",
        "baz" => { "1" => "foo" }
      }
    end
    let(:method_given_args) do
      [
        "foo",
        parameterized_given_args
      ]
    end
    let(:parameterized_expected_args) do
      {
        "_aj_symbol_keys" => ["foo"],
        "foo" => "Foo",
        "bar" => "Bar",
        "baz" => {
          "_aj_symbol_keys" => [],
          "1" => "foo"
        }
      }
    end
    let(:method_expected_args) do
      [
        "foo",
        parameterized_expected_args
      ]
    end
    let(:expected_perform_events) do
      if DependencyHelper.rails7_present?
        ["perform.active_job", "perform_start.active_job"]
      else
        ["perform_start.active_job", "perform.active_job"]
      end
    end
    let(:options) { {} }
    let(:start_agent_args) { { :options => options } }
    before do
      ActiveJob::Base.queue_adapter = :inline

      stub_const("ActiveJobTestJob", Class.new(ActiveJob::Base) do
        def perform(*_args)
        end
      end)

      stub_const("ActiveJobErrorTestJob", Class.new(ActiveJob::Base) do
        def perform
          raise "uh oh"
        end
      end)

      stub_const("ActiveJobErrorWithRetryTestJob", Class.new(ActiveJob::Base) do
        retry_on StandardError, :wait => 0.seconds, :attempts => 2

        def perform
          raise "uh oh"
        end
      end)

      stub_const("ActiveJobCustomQueueTestJob", Class.new(ActiveJob::Base) do
        queue_as :custom_queue

        def perform(*_args)
        end
      end)
    end

    describe "reports action, namespace, tags and params" do
      def perform
        queue_job(ActiveJobTestJob)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)

        allow(Appsignal).to receive(:increment_counter)

        perform

        transaction = last_transaction
        transaction._sample
        expect(transaction).to have_namespace(namespace)
        expect(transaction).to have_action("ActiveJobTestJob#perform")
        expect(transaction).to_not have_error
        expect(transaction).to_not include_metadata
        expect(transaction).to include_params([])
        expect(transaction).to include_tags(
          "active_job_id" => kind_of(String),
          "request_id" => kind_of(String),
          "queue" => queue,
          "executions" => 1
        )
        events = transaction.to_h["events"]
          .sort_by { |e| e["start"] }
          .map { |event| event["name"] }
        expect(events).to eq(expected_perform_events)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        allow(Appsignal).to receive(:increment_counter)

        perform
        last_transaction.complete

        expect(root_span.kind).to eq(:consumer)
        expect(root_span.attributes["appsignal.namespace"]).to eq("background")
        expect(root_span.attributes["appsignal.action_name"]).to eq("ActiveJobTestJob#perform")
        expect(exception_events).to be_empty
        expect(root_span.attributes).to_not have_key("appsignal.metadata")
        expect(JSON.parse(root_span.attributes["appsignal.function.parameters"])).to eq([])
        expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
        expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
        expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
        expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
        # The agent sibling asserts the perform_*.active_job events; mirror that
        # here by checking the event spans exist and nest under the root span.
        expect(event_spans.map(&:name)).to include(*expected_perform_events)
        perform_span = event_spans.find { |s| s.name == "perform.active_job" }
        expect(perform_span).not_to be_nil
        expect(perform_span.parent_span_id).to eq(root_span.span_id)
      end
    end

    context "with custom queue" do
      describe "reports the custom queue as tag" do
        def perform
          queue_job(ActiveJobCustomQueueTestJob)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)

          allow(Appsignal).to receive(:increment_counter)

          perform
          expect(last_transaction).to include_tags("queue" => "custom_queue")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          allow(Appsignal).to receive(:increment_counter)

          perform
          last_transaction.complete

          expect(root_span.attributes["appsignal.tag.queue"]).to eq("custom_queue")
        end
      end
    end

    if DependencyHelper.rails_version >= Gem::Version.new("5.0.0")
      context "with priority" do
        before do
          stub_const("ActiveJobPriorityTestJob", Class.new(ActiveJob::Base) do
            queue_with_priority 10

            def perform(*_args)
            end
          end)
        end

        describe "reports the priority as tag" do
          def perform
            queue_job(ActiveJobPriorityTestJob)
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)

            allow(Appsignal).to receive(:increment_counter)

            perform
            expect(last_transaction).to include_tags("queue" => queue, "priority" => 10)
          end

          it "in collector mode", :collector_mode do
            start_collector_agent

            allow(Appsignal).to receive(:increment_counter)

            perform
            last_transaction.complete

            expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
            expect(root_span.attributes["appsignal.tag.priority"]).to eq(10)
          end
        end
      end
    end

    context "with error" do
      describe "reports the error on the transaction" do
        def perform
          queue_job(ActiveJobErrorTestJob)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)

          allow(Appsignal).to receive(:increment_counter)

          expect { perform }.to raise_error(RuntimeError, "uh oh")

          transaction = last_transaction
          transaction._sample
          expect(transaction).to have_namespace(namespace)
          expect(transaction).to have_action("ActiveJobErrorTestJob#perform")
          expect(transaction).to have_error("RuntimeError", "uh oh")
          expect(transaction).to_not include_metadata
          expect(transaction).to include_params([])
          expect(transaction).to include_tags(
            "active_job_id" => kind_of(String),
            "request_id" => kind_of(String),
            "queue" => queue,
            "executions" => 1
          )
          events = transaction.to_h["events"]
            .sort_by { |e| e["start"] }
            .map { |event| event["name"] }
          expect(events).to eq(expected_perform_events)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          allow(Appsignal).to receive(:increment_counter)

          expect { perform }.to raise_error(RuntimeError, "uh oh")
          last_transaction.complete

          expect(root_span.attributes["appsignal.namespace"]).to eq("background")
          expect(root_span.attributes["appsignal.action_name"])
            .to eq("ActiveJobErrorTestJob#perform")
          event = root_span.events.find { |e| e.name == "exception" }
          expect(event).not_to be_nil
          expect(event.attributes["exception.type"]).to eq("RuntimeError")
          expect(event.attributes["exception.message"]).to eq("uh oh")
          expect(event.attributes["exception.stacktrace"]).to be_a(String)
          expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
          expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
          expect(root_span.attributes).to_not have_key("appsignal.metadata")
          expect(JSON.parse(root_span.attributes["appsignal.function.parameters"])).to eq([])
          expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
          expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
          expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
          expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
        end
      end

      context "with activejob_report_errors set to none" do
        let(:options) { { :activejob_report_errors => "none" } }

        describe "does not report the error" do
          def perform
            queue_job(ActiveJobErrorTestJob)
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)

            allow(Appsignal).to receive(:increment_counter)

            expect { perform }.to raise_error(RuntimeError, "uh oh")
            expect(last_transaction).to_not have_error
          end

          it "in collector mode", :collector_mode do
            start_collector_agent

            allow(Appsignal).to receive(:increment_counter)

            expect { perform }.to raise_error(RuntimeError, "uh oh")
            last_transaction.complete

            expect(exception_events).to be_empty
          end
        end
      end

      if DependencyHelper.rails_version >= Gem::Version.new("7.1.0")
        context "with activejob_report_errors set to discard" do
          let(:options) { { :activejob_report_errors => "discard" } }

          describe "does not report error on first failure" do
            def perform
              with_test_adapter do
                # Prevent the job from being instantly retried so we can test
                # what happens before it's retried
                allow_any_instance_of(ActiveJobErrorWithRetryTestJob).to receive(:retry_job)

                queue_job(ActiveJobErrorWithRetryTestJob)
              end
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)

              perform

              transaction = last_transaction
              transaction._sample
              expect(transaction).to_not have_error
              expect(transaction).to include_tags("executions" => 1)
            end

            it "in collector mode", :collector_mode do
              start_collector_agent

              perform
              last_transaction.complete

              expect(exception_events).to be_empty
              expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
            end
          end

          describe "reports error when discarding the job" do
            def perform
              allow(Appsignal).to receive(:increment_counter)

              with_test_adapter do
                queue_job(ActiveJobErrorWithRetryTestJob)
              end
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)

              expect { perform }.to raise_error(RuntimeError, "uh oh")

              transaction = last_transaction
              transaction._sample
              expect(transaction).to have_error("RuntimeError", "uh oh")
              expect(transaction).to include_tags("executions" => 2)
            end

            it "in collector mode", :collector_mode do
              start_collector_agent

              expect { perform }.to raise_error(RuntimeError, "uh oh")
              last_transaction.complete

              event = exception_events.find do |e|
                e.attributes["exception.type"] == "RuntimeError"
              end
              expect(event).not_to be_nil
              expect(event.attributes["exception.message"]).to eq("uh oh")
              expect(event.attributes["exception.stacktrace"]).to be_a(String)
              expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
              expect(root_span.attributes["appsignal.tag.executions"]).to eq(2)
            end
          end
        end
      end

      if DependencyHelper.rails_version >= Gem::Version.new("5.0.0")
        context "with priority" do
          before do
            stub_const("ActiveJobErrorPriorityTestJob", Class.new(ActiveJob::Base) do
              queue_with_priority 10

              def perform(*_args)
                raise "uh oh"
              end
            end)
          end

          describe "reports the priority as tag" do
            def perform
              queue_job(ActiveJobErrorPriorityTestJob)
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)

              allow(Appsignal).to receive(:increment_counter)

              expect { perform }.to raise_error(RuntimeError, "uh oh")
              expect(last_transaction).to include_tags("queue" => queue, "priority" => 10)
            end

            it "in collector mode", :collector_mode do
              start_collector_agent

              allow(Appsignal).to receive(:increment_counter)

              expect { perform }.to raise_error(RuntimeError, "uh oh")
              last_transaction.complete

              event = root_span.events.find { |e| e.name == "exception" }
              expect(event).not_to be_nil
              expect(event.attributes["exception.type"]).to eq("RuntimeError")
              expect(event.attributes["exception.message"]).to eq("uh oh")
              expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
              expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
              expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
              expect(root_span.attributes["appsignal.tag.priority"]).to eq(10)
            end
          end
        end
      end
    end

    context "with retries" do
      describe "reports the number of retries as executions" do
        def perform
          with_test_adapter do
            queue_job(ActiveJobErrorWithRetryTestJob)
          end
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)

          expect { perform }.to raise_error(RuntimeError, "uh oh")
          expect(last_transaction).to include_tags("executions" => 2)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          expect { perform }.to raise_error(RuntimeError, "uh oh")
          last_transaction.complete

          expect(root_span.attributes["appsignal.tag.executions"]).to eq(2)
        end
      end
    end

    context "when wrapped in another transaction" do
      describe "does not create a new transaction or close the currently open one" do
        def perform(current_transaction)
          set_current_transaction current_transaction
          queue_job(ActiveJobTestJob)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)

          allow(Appsignal).to receive(:increment_counter)

          current_transaction = background_job_transaction
          perform(current_transaction)

          expect(created_transactions.count).to eql(1)

          transaction = current_transaction
          expect(transaction).to_not be_completed
          transaction._sample
          # It does set data on the transaction
          expect(transaction).to have_namespace(namespace)
          expect(transaction).to have_id(current_transaction.transaction_id)
          expect(transaction).to have_action("ActiveJobTestJob#perform")
          expect(transaction).to_not have_error
          expect(transaction).to_not include_metadata
          expect(transaction).to include_params([])
          expect(transaction).to include_tags(
            "active_job_id" => kind_of(String),
            "request_id" => kind_of(String),
            "queue" => queue,
            "executions" => 1
          )

          events = transaction.to_h["events"]
            .reject { |e| e["name"] == "enqueue.active_job" }
            .sort_by { |e| e["start"] }
            .map { |event| event["name"] }
          expect(events).to eq(expected_perform_events)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          allow(Appsignal).to receive(:increment_counter)

          current_transaction = background_job_transaction
          perform(current_transaction)

          expect(created_transactions.count).to eql(1)
          expect(current_transaction).to_not be_completed

          current_transaction.complete

          expect(root_span.attributes["appsignal.namespace"]).to eq("background")
          expect(root_span.attributes["appsignal.action_name"]).to eq("ActiveJobTestJob#perform")
          expect(exception_events).to be_empty
          expect(root_span.attributes).to_not have_key("appsignal.metadata")
          expect(JSON.parse(root_span.attributes["appsignal.function.parameters"])).to eq([])
          expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
          expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
          expect(root_span.attributes["appsignal.tag.queue"]).to eq(queue)
          expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
        end
      end
    end

    context "with distributed trace context" do
      let(:trace_id_hex) { "0af7651916cd43dd8448eb211c80319c" }
      let(:span_id_hex) { "b7ad6b7169203331" }
      let(:traceparent) { "00-#{trace_id_hex}-#{span_id_hex}-01" }

      describe "serializing context onto the job" do
        it "round-trips __otel_headers through serialize/deserialize in collector mode",
          :collector_mode do
          start_collector_agent

          job = ActiveJobTestJob.new
          job.__otel_headers = { "traceparent" => traceparent }
          data = job.serialize

          # Wire-compatible with OpenTelemetry: headers ride as an array of
          # [key, value] pairs (ActiveJob's argument-serializer output), not a
          # hash.
          expect(data["__otel_headers"]).to eq([["traceparent", traceparent]])
          expect(ActiveJobTestJob.deserialize(data).__otel_headers)
            .to eq("traceparent" => traceparent)
        end

        it "leaves the job untouched outside collector mode", :agent_mode do
          start_agent(**start_agent_args)

          job = ActiveJobTestJob.new
          job.__otel_headers = { "traceparent" => traceparent }

          expect(job.serialize).to_not have_key("__otel_headers")
        end
      end

      describe "injecting context on enqueue" do
        before { ActiveJob::Base.queue_adapter = :test }

        # Returns the enqueuing transaction so the example can read its events.
        def enqueue_within_transaction
          transaction = http_request_transaction
          set_current_transaction(transaction)
          ActiveJobTestJob.perform_later
          transaction
        end

        it "writes the producer span's context onto the job in collector mode",
          :collector_mode do
          start_collector_agent
          enqueue_within_transaction
          Appsignal::Transaction.complete_current!

          # The enqueue is a producer event span under the enqueuing
          # transaction, named after the job being enqueued.
          producer = event_spans.find { |s| s.name == "enqueue ActiveJobTestJob job" }
          expect(producer.attributes["appsignal.category"]).to eq("enqueue.active_job")
          expect(producer.kind).to eq(:producer)
          expect(producer.parent_span_id).to eq(root_span.span_id)

          # The serialized job carries that span's context, so the performed job
          # links back to it.
          enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.first
          expect(enqueued["__otel_headers"]).to eq(
            [["traceparent", "00-#{producer.hex_trace_id}-#{producer.hex_span_id}-01"]]
          )
        end

        it "records an enqueue event without wire context in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          transaction = enqueue_within_transaction

          # Exactly one enqueue event: ours. The native `enqueue.active_job`
          # notification is suppressed so it isn't recorded a second time.
          enqueue_events =
            transaction.to_h["events"].select { |event| event["name"] == "enqueue.active_job" }
          expect(enqueue_events.size).to eq(1)
          # The event is titled after the job being enqueued.
          expect(enqueue_events.first["title"]).to eq("enqueue ActiveJobTestJob job")

          enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.first
          expect(enqueued).to_not have_key("__otel_headers")
        end
      end

      describe "suppressing nested adapter enqueue events" do
        before { ActiveJob::Base.queue_adapter = :test }

        # Records whether job enqueue events were suppressed at the moment the
        # adapter enqueued the job -- the window in which a nested adapter
        # integration (Sidekiq, Resque, ...) would record its own event, and
        # which Active Job suppresses so the enqueue is recorded once.
        def suppressed_during_enqueue
          captured = nil
          adapter = ActiveJob::Base.queue_adapter
          allow(adapter).to receive(:enqueue).and_wrap_original do |method, *args|
            captured = Appsignal::Transaction.current.job_enqueue_events_suppressed?
            method.call(*args)
          end

          transaction = http_request_transaction
          set_current_transaction(transaction)
          ActiveJobTestJob.perform_later

          captured
        end

        it "suppresses them while the adapter enqueues in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          expect(suppressed_during_enqueue).to be(true)
        end

        it "suppresses them while the adapter enqueues in collector mode",
          :collector_mode do
          start_collector_agent
          expect(suppressed_during_enqueue).to be(true)
        end
      end

      describe "linking a performed job back to the enqueuer" do
        # A job arrives with OpenTelemetry's serialized array-of-pairs carrier.
        def perform_with_incoming_context
          job_data = ActiveJobTestJob.new.serialize
            .merge("__otel_headers" => [["traceparent", traceparent]])
          perform_active_job { ActiveJob::Base.execute(job_data) }
        end

        it "starts a linked trace in collector mode", :collector_mode do
          start_collector_agent
          perform_with_incoming_context

          # A job is its own unit of work: new trace, linked back to the enqueuer.
          expect(root_span.kind).to eq(:consumer)
          expect(root_span.hex_trace_id).to_not eq(trace_id_hex)
          expect(root_span.links.size).to eq(1)
          link = root_span.links.first.span_context
          expect(link.hex_trace_id).to eq(trace_id_hex)
          expect(link.hex_span_id).to eq(span_id_hex)
        end

        it "does not leak the trace context as metadata in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform_with_incoming_context

          expect(last_transaction.to_h["metadata"].keys).to_not include("__otel_headers")
        end
      end
    end

    context "with params" do
      let(:options) { { :filter_parameters => ["foo"] } }

      describe "filters the configured params" do
        def perform
          queue_job(ActiveJobTestJob, method_given_args)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)

          perform

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash["sample_data"]["params"]).to include(
            [
              "foo",
              {
                "_aj_symbol_keys" => ["foo"],
                "foo" => "[FILTERED]",
                "bar" => "Bar",
                "baz" => { "_aj_symbol_keys" => [], "1" => "foo" }
              }
            ]
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          perform
          last_transaction.complete

          params = JSON.parse(root_span.attributes["appsignal.function.parameters"])
          expect(params).to include(
            [
              "foo",
              {
                "_aj_symbol_keys" => ["foo"],
                "foo" => "[FILTERED]",
                "bar" => "Bar",
                "baz" => { "_aj_symbol_keys" => [], "1" => "foo" }
              }
            ]
          )
        end
      end
    end

    context "with provider_job_id",
      :skip => DependencyHelper.rails_version < Gem::Version.new("5.0.0") do
      before do
        stub_const(
          "ActiveJob::QueueAdapters::AppsignalTestAdapter",
          Class.new(ActiveJob::QueueAdapters::InlineAdapter) do
            # Adapter used in our test suite to add provider data to the job
            # data, as is done by Rails provided ActiveJob adapters.
            #
            # This implementation is based on the
            # `ActiveJob::QueueAdapters::InlineAdapter`.
            def enqueue(job)
              ActiveJob::Base.execute(
                job.serialize.merge("provider_job_id" => "my_provider_job_id")
              )
            end
          end
        )

        stub_const("ProviderWrappedActiveJobTestJob", Class.new(ActiveJob::Base) do
          self.queue_adapter = :appsignal_test

          def perform(*_args)
          end
        end)
      end

      describe "sets provider_job_id as tag" do
        def perform
          queue_job(ProviderWrappedActiveJobTestJob)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)

          perform
          expect(last_transaction).to include_tags(
            "provider_job_id" => "my_provider_job_id"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent

          perform
          last_transaction.complete

          expect(root_span.attributes["appsignal.tag.provider_job_id"])
            .to eq("my_provider_job_id")
        end
      end
    end

    context "with enqueued_at",
      :skip => DependencyHelper.rails_version < Gem::Version.new("6.0.0") do
      before do
        stub_const(
          "ActiveJob::QueueAdapters::AppsignalTestAdapter",
          Class.new(ActiveJob::QueueAdapters::InlineAdapter) do
            # Adapter used in our test suite to add provider data to the job
            # data, as is done by Rails provided ActiveJob adapters.
            #
            # This implementation is based on the
            # `ActiveJob::QueueAdapters::InlineAdapter`.
            def enqueue(job)
              ActiveJob::Base.execute(job.serialize.merge(
                # Is 1 hour before the `let(:time)` definition
                "enqueued_at" => "2001-01-01T09:00:00.000000000Z"
              ))
            end
          end
        )

        stub_const("ProviderWrappedActiveJobTestJob", Class.new(ActiveJob::Base) do
          self.queue_adapter = :appsignal_test

          def perform(*_args)
          end
        end)
      end

      # `have_queue_start` reads agent-only backend state, so this stays
      # agent-only. In collector mode the queue start surfaces as a span event
      # and `transaction_queue_duration` metric (covered in the transaction spec).
      it "sets queue time on transaction", :agent_mode do
        start_agent(**start_agent_args)

        queue_job(ProviderWrappedActiveJobTestJob)

        queue_time = Time.parse("2001-01-01T09:00:00.000000000Z")
        expect(last_transaction).to have_queue_start((queue_time.to_f * 1_000).to_i)
      end
    end

    context "with ActionMailer job" do
      include ActionMailerHelpers

      before do
        stub_const("ActionMailerTestJob", Class.new(ActionMailer::Base) do
          def welcome(_first_arg = nil, _second_arg = nil)
          end
        end)
      end

      context "without params" do
        describe "sets the Action mailer data on the transaction" do
          def perform
            perform_mailer(ActionMailerTestJob, :welcome)
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)

            perform

            transaction = last_transaction
            transaction._sample
            expect(transaction).to have_action("ActionMailerTestJob#welcome")
            expect(transaction).to include_params(
              ["ActionMailerTestJob", "welcome", "deliver_now"] + active_job_args_wrapper
            )
            expect(transaction).to include_tags(
              "active_job_id" => kind_of(String),
              "request_id" => kind_of(String),
              "queue" => "mailers",
              "executions" => 1
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent

            perform
            last_transaction.complete

            expect(root_span.attributes["appsignal.action_name"])
              .to eq("ActionMailerTestJob#welcome")
            expected_params =
              ["ActionMailerTestJob", "welcome", "deliver_now"] + active_job_args_wrapper
            expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
              .to eq(expected_params)
            expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
            expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
            expect(root_span.attributes["appsignal.tag.queue"]).to eq("mailers")
            expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
          end
        end
      end

      context "with multiple arguments" do
        describe "sets the arguments on the transaction" do
          def perform
            perform_mailer(ActionMailerTestJob, :welcome, method_given_args)
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)

            perform

            transaction = last_transaction
            transaction._sample
            expect(transaction).to have_action("ActionMailerTestJob#welcome")
            expect(transaction).to include_params(
              ["ActionMailerTestJob", "welcome",
               "deliver_now"] + active_job_args_wrapper(:args => method_expected_args)
            )
            expect(transaction).to include_tags(
              "active_job_id" => kind_of(String),
              "request_id" => kind_of(String),
              "queue" => "mailers",
              "executions" => 1
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent

            perform
            last_transaction.complete

            expect(root_span.attributes["appsignal.action_name"])
              .to eq("ActionMailerTestJob#welcome")
            expected_params =
              ["ActionMailerTestJob", "welcome",
               "deliver_now"] + active_job_args_wrapper(:args => method_expected_args)
            expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
              .to eq(expected_params)
            expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
            expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
            expect(root_span.attributes["appsignal.tag.queue"]).to eq("mailers")
            expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
          end
        end
      end

      if DependencyHelper.rails_version >= Gem::Version.new("5.2.0")
        context "with parameterized arguments" do
          describe "sets the arguments on the transaction" do
            def perform
              perform_mailer(ActionMailerTestJob, :welcome, parameterized_given_args)
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)

              perform

              transaction = last_transaction
              transaction._sample
              expect(transaction).to have_action("ActionMailerTestJob#welcome")
              expect(transaction).to include_params(
                [
                  "ActionMailerTestJob",
                  "welcome",
                  "deliver_now"
                ] + active_job_args_wrapper(:params => parameterized_expected_args)
              )
              expect(transaction).to include_tags(
                "active_job_id" => kind_of(String),
                "request_id" => kind_of(String),
                "queue" => "mailers",
                "executions" => 1
              )
            end

            it "in collector mode", :collector_mode do
              start_collector_agent

              perform
              last_transaction.complete

              expect(root_span.attributes["appsignal.action_name"])
                .to eq("ActionMailerTestJob#welcome")
              expected_params =
                [
                  "ActionMailerTestJob",
                  "welcome",
                  "deliver_now"
                ] + active_job_args_wrapper(:params => parameterized_expected_args)
              expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
                .to eq(expected_params)
              expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
              expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
              expect(root_span.attributes["appsignal.tag.queue"]).to eq("mailers")
              expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
            end
          end
        end
      end
    end

    if DependencyHelper.rails_version >= Gem::Version.new("6.0.0")
      context "with ActionMailer MailDeliveryJob job" do
        include ActionMailerHelpers

        before do
          stub_const("ActionMailerTestMailDeliveryJob", Class.new(ActionMailer::Base) do
            self.delivery_job = ActionMailer::MailDeliveryJob

            def welcome(*_args)
            end
          end)
        end

        describe "sets the Action mailer data on the transaction" do
          def perform
            perform_mailer(ActionMailerTestMailDeliveryJob, :welcome)
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)

            perform

            transaction = last_transaction
            transaction._sample
            expect(transaction).to have_action("ActionMailerTestMailDeliveryJob#welcome")
            expect(transaction).to include_params(
              [
                "ActionMailerTestMailDeliveryJob",
                "welcome",
                "deliver_now",
                { active_job_internal_key => ["args"], "args" => [] }
              ]
            )
            expect(transaction).to include_tags(
              "active_job_id" => kind_of(String),
              "request_id" => kind_of(String),
              "queue" => "mailers",
              "executions" => 1
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent

            perform
            last_transaction.complete

            expect(root_span.attributes["appsignal.action_name"])
              .to eq("ActionMailerTestMailDeliveryJob#welcome")
            expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
              .to eq([
                "ActionMailerTestMailDeliveryJob",
                "welcome",
                "deliver_now",
                { active_job_internal_key => ["args"], "args" => [] }
              ])
            expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
            expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
            expect(root_span.attributes["appsignal.tag.queue"]).to eq("mailers")
            expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
          end
        end

        context "with method arguments" do
          describe "sets the Action mailer data on the transaction" do
            def perform
              perform_mailer(ActionMailerTestMailDeliveryJob, :welcome, method_given_args)
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)

              perform

              transaction = last_transaction
              transaction._sample
              expect(transaction).to have_action("ActionMailerTestMailDeliveryJob#welcome")
              expect(transaction).to include_params(
                [
                  "ActionMailerTestMailDeliveryJob",
                  "welcome",
                  "deliver_now",
                  {
                    active_job_internal_key => ["args"],
                    "args" => method_expected_args
                  }
                ]
              )
              expect(transaction).to include_tags(
                "active_job_id" => kind_of(String),
                "request_id" => kind_of(String),
                "queue" => "mailers",
                "executions" => 1
              )
            end

            it "in collector mode", :collector_mode do
              start_collector_agent

              perform
              last_transaction.complete

              expect(root_span.attributes["appsignal.action_name"])
                .to eq("ActionMailerTestMailDeliveryJob#welcome")
              expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
                .to eq([
                  "ActionMailerTestMailDeliveryJob",
                  "welcome",
                  "deliver_now",
                  {
                    active_job_internal_key => ["args"],
                    "args" => method_expected_args
                  }
                ])
              expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
              expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
              expect(root_span.attributes["appsignal.tag.queue"]).to eq("mailers")
              expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
            end
          end
        end

        context "with parameterized arguments" do
          describe "sets the Action mailer data on the transaction" do
            def perform
              perform_mailer(ActionMailerTestMailDeliveryJob, :welcome, parameterized_given_args)
            end

            it "in agent mode", :agent_mode do
              start_agent(**start_agent_args)

              perform

              transaction = last_transaction
              transaction._sample
              expect(transaction).to have_action("ActionMailerTestMailDeliveryJob#welcome")
              expect(transaction).to include_params(
                [
                  "ActionMailerTestMailDeliveryJob",
                  "welcome",
                  "deliver_now",
                  {
                    active_job_internal_key => ["params", "args"],
                    "args" => [],
                    "params" => parameterized_expected_args
                  }
                ]
              )
              expect(transaction).to include_tags(
                "active_job_id" => kind_of(String),
                "request_id" => kind_of(String),
                "queue" => "mailers",
                "executions" => 1
              )
            end

            it "in collector mode", :collector_mode do
              start_collector_agent

              perform
              last_transaction.complete

              expect(root_span.attributes["appsignal.action_name"])
                .to eq("ActionMailerTestMailDeliveryJob#welcome")
              expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
                .to eq([
                  "ActionMailerTestMailDeliveryJob",
                  "welcome",
                  "deliver_now",
                  {
                    active_job_internal_key => ["params", "args"],
                    "args" => [],
                    "params" => parameterized_expected_args
                  }
                ])
              expect(root_span.attributes["appsignal.tag.active_job_id"]).to be_a(String)
              expect(root_span.attributes["appsignal.tag.request_id"]).to be_a(String)
              expect(root_span.attributes["appsignal.tag.queue"]).to eq("mailers")
              expect(root_span.attributes["appsignal.tag.executions"]).to eq(1)
            end
          end
        end
      end
    end

    def with_test_adapter
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.performed_jobs.clear
      ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
      ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
      yield
    ensure
      ActiveJob::Base.queue_adapter = :inline # Restore to default
    end

    def perform_active_job(&block)
      Timecop.freeze(time, &block)
    end

    def queue_job(job_class, args = nil)
      perform_active_job do
        if args
          job_class.perform_later(args)
        else
          job_class.perform_later
        end
      end
    end

    def perform_mailer(mailer, method, args = nil)
      perform_active_job { perform_action_mailer(mailer, method, args) }
    end

    def active_job_internal_key
      if DependencyHelper.ruby_version >= Gem::Version.new("2.7.0")
        "_aj_ruby2_keywords"
      else
        "_aj_symbol_keys"
      end
    end
  end

  # The agent has no in-memory metric readout, so agent mode keeps the
  # `increment_counter` mock while collector mode asserts the same metric
  # reaches the OpenTelemetry backend. Only the metric is asserted here — the
  # transaction-shape coverage stays agent-only (in the instrumentation describe
  # above), since action/namespace/tags aren't implemented in collector mode
  # yet. Self-contained so it doesn't inherit the `ActiveJobClassInstrumentation`
  # group's parameterized `start_agent`; `start_agent` comes from the mode
  # contexts.
  describe "emitting the queue job count metric" do
    before do
      ActiveJob::Base.queue_adapter = :inline
      stub_const("ActiveJobTestJob", Class.new(ActiveJob::Base) do
        def perform(*_args)
        end
      end)
    end

    def perform
      ActiveJobTestJob.perform_later
    end

    it "in agent mode", :agent_mode do
      start_agent

      expect(Appsignal).to receive(:increment_counter)
        .with("active_job_queue_job_count", 1, { :queue => "default", :status => :processed })

      perform
    end

    it "in collector mode", :collector_mode do
      start_collector_agent

      perform

      snapshot = metric_snapshot("active_job_queue_job_count")
      expect(snapshot).not_to be_nil
      expect(snapshot.data_points.first.value).to eq(1.0)
      expect(snapshot.data_points.first.attributes).to include(
        "queue" => "default",
        "status" => "processed"
      )
    end
  end

  # A failing job emits the job count metric a second time, tagged
  # `status: failed`. Self-contained, same rationale as the describe above.
  describe "emitting the failed job count metric" do
    before do
      ActiveJob::Base.queue_adapter = :inline
      stub_const("ActiveJobFailingJob", Class.new(ActiveJob::Base) do
        def perform(*_args)
          raise "uh oh"
        end
      end)
    end

    def perform
      ActiveJobFailingJob.perform_later
    rescue RuntimeError
      # The inline adapter re-raises the job's error; swallow it so the
      # example can assert on the metric the hook emits in its `ensure`.
    end

    it "in agent mode", :agent_mode do
      start_agent

      allow(Appsignal).to receive(:increment_counter) # the `processed` call
      expect(Appsignal).to receive(:increment_counter)
        .with("active_job_queue_job_count", 1, { :queue => "default", :status => :failed })

      perform
    end

    it "in collector mode", :collector_mode do
      start_collector_agent

      perform

      snapshot = metric_snapshot("active_job_queue_job_count")
      expect(snapshot).not_to be_nil
      failed = snapshot.data_points.find { |point| point.attributes["status"] == "failed" }
      expect(failed).not_to be_nil
      expect(failed.value).to eq(1.0)
      expect(failed.attributes).to include("queue" => "default", "status" => "failed")
    end
  end

  # A job with a priority emits an additional `priority_job_count` metric.
  if DependencyHelper.rails_version >= Gem::Version.new("5.0.0")
    describe "emitting the priority job count metric" do
      before do
        ActiveJob::Base.queue_adapter = :inline
        stub_const("ActiveJobPriorityJob", Class.new(ActiveJob::Base) do
          queue_with_priority 10

          def perform(*_args)
          end
        end)
      end

      def perform
        ActiveJobPriorityJob.perform_later
      end

      it "in agent mode", :agent_mode do
        start_agent

        allow(Appsignal).to receive(:increment_counter) # the queue_job_count call
        expect(Appsignal).to receive(:increment_counter).with(
          "active_job_queue_priority_job_count",
          1,
          { :queue => "default", :priority => 10, :status => :processed }
        )

        perform
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        snapshot = metric_snapshot("active_job_queue_priority_job_count")
        expect(snapshot).not_to be_nil
        point = snapshot.data_points.first
        expect(point.value).to eq(1.0)
        expect(point.attributes).to include(
          "queue" => "default",
          "priority" => 10,
          "status" => "processed"
        )
      end
    end
  end

  # A job carrying an `enqueued_at` reports its queue time as a distribution.
  context "with enqueued_at",
    :skip => DependencyHelper.rails_version < Gem::Version.new("6.0.0") do
    describe "emitting the queue time metric" do
      before do
        stub_const(
          "ActiveJob::QueueAdapters::AppsignalTestAdapter",
          Class.new(ActiveJob::QueueAdapters::InlineAdapter) do
            # Inject an `enqueued_at` an hour before the frozen "now" below.
            def enqueue(job)
              ActiveJob::Base.execute(
                job.serialize.merge("enqueued_at" => "2001-01-01T09:00:00.000000000Z")
              )
            end
          end
        )
        stub_const("ActiveJobQueueTimeJob", Class.new(ActiveJob::Base) do
          self.queue_adapter = :appsignal_test

          def perform(*_args)
          end
        end)
      end

      def perform
        Timecop.freeze(Time.parse("2001-01-01T10:00:00.000000000Z")) do
          ActiveJobQueueTimeJob.perform_later
        end
      end

      it "in agent mode", :agent_mode do
        start_agent

        allow(Appsignal).to receive(:add_distribution_value)

        perform

        # One hour of queue time, in milliseconds.
        expect(Appsignal).to have_received(:add_distribution_value)
          .with("active_job_queue_time", 3_600_000.0, :queue => "default")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        snapshot = metric_snapshot("active_job_queue_time")
        expect(snapshot).not_to be_nil
        expect(snapshot.instrument_kind).to eq(:histogram)
        point = snapshot.data_points.first
        expect(point.count).to eq(1)
        expect(point.sum).to eq(3_600_000.0)
        expect(point.attributes).to include("queue" => "default")
      end
    end
  end
end
