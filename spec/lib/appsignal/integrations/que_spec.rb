if DependencyHelper.que_present?
  require "appsignal/integrations/que"

  describe Appsignal::Integrations::QuePlugin do
    describe "#_run" do
      let(:job_attrs) do
        {
          :job_id => 123,
          :queue => "dfl",
          :job_class => "MyQueJob",
          :priority => 100,
          :args => %w[post_id_123 user_id_123],
          :run_at => fixed_time,
          :error_count => 0
        }.tap do |hash|
          hash[:kwargs] = {} if DependencyHelper.que2_present?
        end
      end
      let(:job) do
        Class.new(::Que::Job) do
          def run(post_id, user_id)
          end
        end
      end
      let(:instance) { job.new(job_attrs) }
      before do
        allow(Que).to receive(:execute)
      end

      def perform_que_job(job)
        job._run
      end

      context "without exception" do
        def perform
          perform_que_job(instance)
        end

        describe "creates a transaction for a job" do
          it "in agent mode", :agent_mode do
            start_agent
            expect { perform }.to change { created_transactions.length }.by(1)

            transaction = last_transaction
            expect(transaction).to have_id
            expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
            expect(transaction).to have_action("MyQueJob#run")
            expect(transaction).to_not have_error
            expect(transaction).to include_event(
              "body" => "",
              "body_format" => Appsignal::EventFormatter::DEFAULT,
              "count" => 1,
              "name" => "perform_job.que",
              "title" => ""
            )
            expect(transaction).to include_params(
              "arguments" => %w[post_id_123 user_id_123]
            )
            if DependencyHelper.que2_present?
              expect(transaction).to include_params(
                "keyword_arguments" => {}
              )
            else
              expect(transaction).to_not include_params(
                "keyword_arguments" => anything
              )
            end
            expect(transaction).to include_tags(
              "attempts" => 0,
              "id" => 123,
              "priority" => 100,
              "queue" => "dfl",
              "run_at" => fixed_time.to_s
            )
            expect(transaction).to be_completed
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            expect { perform }.to change { created_transactions.length }.by(1)

            expect(root_span.kind).to eq(:consumer)
            expect(root_span.attributes["appsignal.namespace"])
              .to eq("background")
            expect(root_span.attributes["appsignal.action_name"]).to eq("MyQueJob#run")
            expect(exception_events).to be_empty
            span = event_spans.find { |s| s.name == "perform_job.que" }
            expect(span).not_to be_nil
            expect(span.parent_span_id).to eq(root_span.span_id)
            expect(span.attributes).not_to have_key("appsignal.body")
            expect(span.attributes["appsignal.category"]).to eq("perform_job.que")
            expect(scope_of(root_span)).to eq(["appsignal-ruby/que", Appsignal::VERSION])
            expect(scope_of(span)).to eq(["appsignal-ruby/que", Appsignal::VERSION])
            expected_params = { "arguments" => %w[post_id_123 user_id_123] }
            expected_params["keyword_arguments"] = {} if DependencyHelper.que2_present?
            expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
              .to eq(expected_params)
            expect(root_span.attributes["appsignal.tag.attempts"]).to eq(0)
            expect(root_span.attributes["appsignal.tag.id"]).to eq(123)
            expect(root_span.attributes["appsignal.tag.priority"]).to eq(100)
            expect(root_span.attributes["appsignal.tag.queue"]).to eq("dfl")
            expect(root_span.attributes["appsignal.tag.run_at"]).to eq(fixed_time.to_s)
            expect(last_transaction).to be_completed
          end
        end
      end

      context "with exception" do
        let(:error) { ExampleException.new("oh no!") }

        before do
          allow(instance).to receive(:run).and_raise(error)
        end

        def perform
          expect do
            perform_que_job(instance)
          end.to raise_error(ExampleException)
        end

        describe "reports exceptions and re-raises them" do
          it "in agent mode", :agent_mode do
            start_agent
            expect { perform }.to change { created_transactions.length }.by(1)

            transaction = last_transaction
            expect(transaction).to have_id
            expect(transaction).to have_action("MyQueJob#run")
            expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
            expect(transaction).to have_error(error.class.name, error.message)
            expect(transaction).to include_params(
              "arguments" => %w[post_id_123 user_id_123]
            )
            expect(transaction).to include_tags(
              "attempts" => 0,
              "id" => 123,
              "priority" => 100,
              "queue" => "dfl",
              "run_at" => fixed_time.to_s
            )
            expect(transaction).to be_completed
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            expect { perform }.to change { created_transactions.length }.by(1)

            expect(root_span.kind).to eq(:consumer)
            expect(root_span.attributes["appsignal.action_name"]).to eq("MyQueJob#run")
            expect(root_span.attributes["appsignal.namespace"])
              .to eq("background")
            event = exception_events.find { |e| e.attributes["exception.type"] == error.class.name }
            expect(event).not_to be_nil
            expect(event.attributes["exception.message"]).to eq(error.message)
            expect(event.attributes["exception.stacktrace"]).to be_a(String)
            expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
            expected_params = { "arguments" => %w[post_id_123 user_id_123] }
            expected_params["keyword_arguments"] = {} if DependencyHelper.que2_present?
            expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
              .to eq(expected_params)
            expect(root_span.attributes["appsignal.tag.attempts"]).to eq(0)
            expect(root_span.attributes["appsignal.tag.id"]).to eq(123)
            expect(root_span.attributes["appsignal.tag.priority"]).to eq(100)
            expect(root_span.attributes["appsignal.tag.queue"]).to eq("dfl")
            expect(root_span.attributes["appsignal.tag.run_at"]).to eq(fixed_time.to_s)
            expect(last_transaction).to be_completed
          end
        end
      end

      context "with error" do
        let(:error) { ExampleStandardError.new("oh no!") }

        before do
          allow(instance).to receive(:run).and_raise(error)
        end

        def perform
          perform_que_job(instance)
        end

        # Que 0.x handles the error inside its own `_run` and counts the failed
        # attempt there. That happens before the plugin reads the job attributes,
        # so it reports one attempt. Que 1 and up leave the count to the worker,
        # so they still report none here.
        let(:expected_attempts) { DependencyHelper.que1_present? ? 0 : 1 }

        describe "reports errors and does not re-raise them" do
          it "in agent mode", :agent_mode do
            start_agent
            expect { perform }.to change { created_transactions.length }.by(1)

            transaction = last_transaction
            expect(transaction).to have_id
            expect(transaction).to have_action("MyQueJob#run")
            expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
            expect(transaction).to have_error(error.class.name, error.message)
            expect(transaction).to include_params(
              "arguments" => %w[post_id_123 user_id_123]
            )
            expect(transaction).to include_tags(
              "attempts" => expected_attempts,
              "id" => 123,
              "priority" => 100,
              "queue" => "dfl",
              "run_at" => fixed_time.to_s
            )
            expect(transaction).to be_completed
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            expect { perform }.to change { created_transactions.length }.by(1)

            expect(root_span.kind).to eq(:consumer)
            expect(root_span.attributes["appsignal.action_name"]).to eq("MyQueJob#run")
            expect(root_span.attributes["appsignal.namespace"])
              .to eq("background")
            event = exception_events.find { |e| e.attributes["exception.type"] == error.class.name }
            expect(event).not_to be_nil
            expect(event.attributes["exception.message"]).to eq(error.message)
            expect(event.attributes["exception.stacktrace"]).to be_a(String)
            expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
            expected_params = { "arguments" => %w[post_id_123 user_id_123] }
            expected_params["keyword_arguments"] = {} if DependencyHelper.que2_present?
            expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
              .to eq(expected_params)
            expect(root_span.attributes["appsignal.tag.attempts"]).to eq(expected_attempts)
            expect(root_span.attributes["appsignal.tag.id"]).to eq(123)
            expect(root_span.attributes["appsignal.tag.priority"]).to eq(100)
            expect(root_span.attributes["appsignal.tag.queue"]).to eq("dfl")
            expect(root_span.attributes["appsignal.tag.run_at"]).to eq(fixed_time.to_s)
            expect(last_transaction).to be_completed
          end
        end
      end

      if DependencyHelper.que2_present?
        context "with keyword argument" do
          let(:job_attrs) do
            {
              :job_id => 123,
              :queue => "dfl",
              :job_class => "MyQueJob",
              :priority => 100,
              :args => %w[post_id_123],
              :kwargs => { :user_id => "user_id_123" },
              :run_at => fixed_time,
              :error_count => 0
            }
          end
          let(:job) do
            Class.new(::Que::Job) do
              def run(post_id, user_id: nil)
              end
            end
          end

          def perform
            perform_que_job(instance)
          end

          describe "reports keyword arguments as parameters" do
            it "in agent mode", :agent_mode do
              start_agent
              perform

              expect(last_transaction).to include_params(
                "arguments" => %w[post_id_123],
                "keyword_arguments" => { "user_id" => "user_id_123" }
              )
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(JSON.parse(root_span.attributes["appsignal.function.parameters"]))
                .to eq(
                  "arguments" => %w[post_id_123],
                  "keyword_arguments" => { "user_id" => "user_id_123" }
                )
            end
          end
        end
      end

      context "when action set in job" do
        let(:job) do
          Class.new(::Que::Job) do
            def run(*_args)
              Appsignal.set_action("MyCustomJob#perform")
            end
          end
        end

        def perform
          perform_que_job(instance)
        end

        describe "uses the custom action" do
          it "in agent mode", :agent_mode do
            start_agent
            perform

            transaction = last_transaction
            expect(transaction).to have_action("MyCustomJob#perform")
            expect(transaction).to be_completed
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(root_span.attributes["appsignal.action_name"])
              .to eq("MyCustomJob#perform")
            expect(last_transaction).to be_completed
          end
        end
      end

      # Que only has tags from version 1.0 on, and they are the only carrier the
      # trace context can ride on, so this is Que 1 and up only.
      context "with incoming trace context", :if => DependencyHelper.que1_present? do
        let(:trace_id_hex) { "0af7651916cd43dd8448eb211c80319c" }
        let(:span_id_hex) { "b7ad6b7169203331" }
        let(:traceparent) { "00-#{trace_id_hex}-#{span_id_hex}-01" }
        # OpenTelemetry's Que instrumentation carries the trace context as
        # "key:value" tag strings under the job's `data` attribute.
        let(:job_attrs) do
          super().merge(:data => { :tags => ["traceparent:#{traceparent}"] })
        end

        def perform
          perform_que_job(instance)
        end

        it "in agent mode", :agent_mode do
          start_agent
          expect { perform }.to change { created_transactions.length }.by(1)
          expect(last_transaction).to be_completed
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          # The job continues the enqueuer's trace as a child and links back to it.
          expect(root_span.kind).to eq(:consumer)
          expect(root_span.hex_trace_id).to eq(trace_id_hex)
          expect(root_span.parent_span_id.unpack1("H*")).to eq(span_id_hex)
          expect(root_span.links.size).to eq(1)
          link_context = root_span.links.first.span_context
          expect(link_context.hex_trace_id).to eq(trace_id_hex)
          expect(link_context.hex_span_id).to eq(span_id_hex)
        end
      end
    end
  end

  # Enqueue-side propagation reads context from the job's tags. The carrier
  # (tags serialized into the job's `data`) is identical on Que 1 and Que 2, so
  # this is covered on both versions. Que 0.x has no tags, so there the enqueue
  # is only recorded as an event and nothing is propagated.
  describe Appsignal::Integrations::QueClientPlugin do
    let(:job) do
      Class.new(::Que::Job) do
        def self.name
          "MyQueJob"
        end
      end
    end

    # Capture what Que would persist, without needing a database.
    let(:captured) { {} }
    before do
      allow(Que).to receive(:execute) do |command, values|
        captured[:values] = values if command == :insert_job
        [{}]
      end

      # After enqueueing, Que 0.x wakes a worker through its adapter, which
      # needs a database connection.
      unless DependencyHelper.que1_present?
        allow(Que).to receive(:adapter)
          .and_return(double(:wake_worker_after_commit => nil))
      end
    end

    # The arguments are the fifth value Que passes to its `:insert_job` query on
    # every version. Que 1 and up serialise them to JSON first; Que 0.x hands
    # over the array itself.
    def enqueued_args
      args = captured[:values] && captured[:values][4]
      args.is_a?(String) ? JSON.parse(args) : args
    end

    # `data` is the last value Que passes to its `:insert_job` query on both Que
    # 1 and Que 2 (Que 2 inserts `kwargs` before it, shifting its index); the
    # tags live under it as a JSON string.
    def enqueued_tags
      data = captured[:values]&.last
      data ? JSON.parse(data)["tags"] : nil
    end

    # Que 0.x has no `job_options` keyword and no tags. It reads its scheduling
    # options from top-level keys in a trailing hash instead. So the tags are
    # only passed on Que 1 and up.
    def enqueue(tags: ["user:42"])
      if DependencyHelper.que1_present?
        job.enqueue("post_id_123", :job_options => { :tags => tags })
      else
        job.enqueue("post_id_123")
      end
    end

    # Whatever the plugin records or injects, it must leave the job's own
    # arguments alone. This matters most on Que 0.x, which turns any keyword
    # argument it does not recognise into an extra job argument. A keyword the
    # plugin adds to the call itself, such as a `job_options` the caller never
    # passed, would be persisted as a job argument and break the job when it
    # runs.
    def expect_job_arguments_untouched
      expect(enqueued_args).to eq(["post_id_123"])
    end

    context "with an active transaction" do
      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)

        enqueue

        # Records an enqueue event on the transaction, titled after the job.
        event = transaction.to_h["events"].find { |e| e["name"] == "enqueue.que" }
        expect(event).to_not be_nil
        expect(event["title"]).to eq("enqueue MyQueJob job")
        # No wire context in agent mode; only the user's own tag persists.
        expect(enqueued_tags).to eq(["user:42"]) if DependencyHelper.que1_present?
        expect_job_arguments_untouched
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)

        enqueue
        Appsignal::Transaction.complete_current!

        # The enqueue is a producer event span under the active transaction,
        # named after the job being enqueued.
        producer = event_spans.find { |s| s.name == "enqueue MyQueJob job" }
        expect(producer.attributes["appsignal.category"]).to eq("enqueue.que")
        expect(scope_of(producer)).to eq(["appsignal-ruby/que", Appsignal::VERSION])
        expect(producer.kind).to eq(:producer)
        expect(producer.parent_span_id).to eq(root_span.span_id)

        if DependencyHelper.que1_present?
          # The job carries the producer span's context as a traceparent tag,
          # alongside the user's own tag.
          expect(enqueued_tags).to include("user:42")
          expect(enqueued_tags)
            .to include("traceparent:00-#{producer.hex_trace_id}-#{producer.hex_span_id}-01")
        end
        expect_job_arguments_untouched
      end

      it "skips propagation rather than break the enqueue when tags are full",
        :collector_mode, :if => DependencyHelper.que1_present? do
        start_collector_agent
        set_current_transaction(http_request_transaction)

        # Already at Que's 5-tag limit; adding trace context would exceed it, so
        # propagation is skipped and the enqueue still succeeds unchanged.
        full = %w[t1 t2 t3 t4 t5]
        expect { enqueue(:tags => full) }.to_not raise_error
        Appsignal::Transaction.complete_current!

        expect(enqueued_tags).to eq(full)
      end
    end

    context "without an active transaction" do
      it "in agent mode", :agent_mode do
        start_agent

        # No transaction to attach to: a transparent pass-through.
        expect { enqueue }.to_not raise_error
        expect(enqueued_tags).to eq(["user:42"]) if DependencyHelper.que1_present?
        expect_job_arguments_untouched
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        enqueue

        # No transaction to attach to: nothing recorded, nothing injected.
        expect(span_exporter.finished_spans.map(&:name)).to_not include("enqueue.que")
        expect(enqueued_tags).to eq(["user:42"]) if DependencyHelper.que1_present?
        expect_job_arguments_untouched
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

        enqueue_suppressed(transaction)

        # The outer integration records the enqueue, so this one doesn't.
        event_names = transaction.to_h["events"].map { |event| event["name"] }
        expect(event_names).to_not include("enqueue.que")
        expect_job_arguments_untouched
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)

        enqueue_suppressed(transaction)
        Appsignal::Transaction.complete_current!

        # No producer span for the suppressed enqueue...
        expect(span_exporter.finished_spans.map(&:name)).to_not include("enqueue.que")
        # ...but the trace context is still injected so the job links back.
        if DependencyHelper.que1_present?
          expect(enqueued_tags).to include(a_string_starting_with("traceparent:"))
        end
        expect_job_arguments_untouched
      end
    end

    # `bulk_enqueue` is Que 2 only. The whole batch shares one `job_options`, so
    # it records a single producer event and the inner enqueues are pass-throughs.
    describe "#bulk_enqueue", :if => DependencyHelper.que2_present? do
      before do
        # Que's bulk path constantizes the job class by name, so it needs a real
        # constant (the single-enqueue path uses `new` and doesn't).
        stub_const("MyQueJob", job)
        allow(Que).to receive(:transaction).and_yield
        allow(Que).to receive(:execute) do |command, values|
          captured[:values] = values if command == :bulk_insert_jobs
          [{}]
        end
      end

      def bulk_enqueue(tags: ["user:42"])
        job.bulk_enqueue(:job_options => { :tags => tags }) do
          job.enqueue("post_id_123")
          job.enqueue("post_id_456")
        end
      end

      context "with an active transaction" do
        it "records one producer event for the batch in agent mode", :agent_mode do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          bulk_enqueue

          # One event for the whole batch, titled after the job -- the inner
          # enqueues don't add their own.
          bulk_events =
            transaction.to_h["events"].select { |e| e["name"] == "bulk_enqueue.que" }
          expect(bulk_events.size).to eq(1)
          expect(bulk_events.first["title"]).to eq("bulk enqueue MyQueJob jobs")
          event_names = transaction.to_h["events"].map { |event| event["name"] }
          expect(event_names).to_not include("enqueue.que")
          expect(enqueued_tags).to eq(["user:42"])
        end

        it "injects the batch's context once in collector mode", :collector_mode do
          start_collector_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          bulk_enqueue
          Appsignal::Transaction.complete_current!

          producers = event_spans.select { |s| s.name == "bulk enqueue MyQueJob jobs" }
          expect(producers.size).to eq(1)
          producer = producers.first
          expect(producer.attributes["appsignal.category"]).to eq("bulk_enqueue.que")
          expect(producer.kind).to eq(:producer)
          expect(producer.parent_span_id).to eq(root_span.span_id)

          # Every job in the batch carries the one producer span's context.
          expect(enqueued_tags).to include("user:42")
          expect(enqueued_tags)
            .to include("traceparent:00-#{producer.hex_trace_id}-#{producer.hex_span_id}-01")
        end

        it "skips propagation rather than break the enqueue when tags are full",
          :collector_mode do
          start_collector_agent
          set_current_transaction(http_request_transaction)

          full = %w[t1 t2 t3 t4 t5]
          expect { bulk_enqueue(:tags => full) }.to_not raise_error
          Appsignal::Transaction.complete_current!

          expect(enqueued_tags).to eq(full)
        end
      end

      context "when job enqueue events are suppressed" do
        # As happens under Active Job, which records the enqueue itself.
        def bulk_enqueue_suppressed(transaction)
          transaction.suppress_job_enqueue_events { bulk_enqueue }
        end

        it "in agent mode", :agent_mode do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          bulk_enqueue_suppressed(transaction)

          # The outer integration records the enqueue, so this one doesn't.
          event_names = transaction.to_h["events"].map { |event| event["name"] }
          expect(event_names).to_not include("bulk_enqueue.que")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)

          bulk_enqueue_suppressed(transaction)
          Appsignal::Transaction.complete_current!

          # No producer span for the suppressed batch...
          expect(span_exporter.finished_spans.map(&:name)).to_not include("bulk_enqueue.que")
          # ...but the trace context is still injected so the jobs link back.
          expect(enqueued_tags).to include(a_string_starting_with("traceparent:"))
        end
      end
    end
  end
end
