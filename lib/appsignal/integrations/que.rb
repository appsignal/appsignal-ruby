# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    #
    # Reads and writes W3C trace context the way OpenTelemetry's Que
    # instrumentation does: as `"key:value"` strings in the job's tags array
    # (the only carrier Que's enqueue API exposes). Collector mode only.
    module QueTraceContext
      module_function

      # Read the incoming context off the job's tags. Splits each `"key:value"`
      # tag on the first colon back into a carrier hash, then extracts. Returns
      # an `OpenTelemetry::Context`, or `nil` outside collector mode.
      def extract(tags)
        Appsignal::OpenTelemetry.if_started do
          carrier = Array(tags)
            .map { |tag| tag.split(":", 2) }
            .select { |pair| pair.size == 2 }
            .to_h
          ::OpenTelemetry.propagation.extract(carrier)
        end
      end
    end

    # @!visibility private
    module QuePlugin
      def _run(*args)
        local_attrs = respond_to?(:que_attrs) ? que_attrs : attrs

        # Read the incoming trace context off the job's tags so the transaction
        # links back to the enqueuer. No-op outside collector mode.
        transaction =
          Appsignal::Transaction.create(
            Appsignal::Transaction::BACKGROUND_JOB,
            :opentelemetry_context => QueTraceContext.extract(local_attrs.dig(:data, :tags))
          )

        begin
          Appsignal.instrument("perform_job.que") { super }
        rescue Exception => error
          transaction.set_error(error)
          raise error
        ensure
          transaction.set_action_if_nil("#{local_attrs[:job_class]}#run")
          transaction.add_params_if_nil do
            {
              :arguments => local_attrs[:args]
            }.tap do |hash|
              hash[:keyword_arguments] = local_attrs[:kwargs] if local_attrs.key?(:kwargs)
            end
          end
          transaction.add_tags(
            "id" => local_attrs[:job_id] || local_attrs[:id],
            "queue" => local_attrs[:queue],
            "run_at" => local_attrs[:run_at].to_s,
            "priority" => local_attrs[:priority],
            "attempts" => local_attrs[:error_count].to_i
          )
          Appsignal::Transaction.complete_current!
        end
      end
    end

    # @!visibility private
    #
    # Prepended to `Que::Job`'s singleton so it records each enqueue as an
    # `enqueue.que` event under the active transaction. Like all AppSignal
    # events, it only records when there's an active transaction (e.g. enqueuing
    # from within a web request or another job); otherwise it's a transparent
    # pass-through.
    module QueClientPlugin
      def enqueue(*_args, job_options: {}, **_rest)
        # Inside a `bulk_enqueue` block the batch is recorded once by the
        # `bulk_enqueue` wrapper, so each inner enqueue is a pass-through to
        # avoid recording an event per job.
        return super if Thread.current[:appsignal_que_bulk_enqueue]

        # Under Active Job the enqueue is already recorded as an
        # `enqueue.active_job` event, so skip recording it again here.
        return super if Appsignal::Transaction.current? &&
          Appsignal::Transaction.current.job_enqueue_events_suppressed?

        # Resolve the job class the way Que does: an explicit `:job_class`, else
        # the class `enqueue` was called on.
        title = "enqueue #{job_options[:job_class] || name} job"
        Appsignal.instrument("enqueue.que", title) { super }
      end
    end

    # @!visibility private
    #
    # `bulk_enqueue` exists only on Que 2+, so this lives in its own module that
    # the hook prepends only when Que has the method -- otherwise we'd define a
    # `bulk_enqueue` on Que versions that have none. The whole batch records a
    # single `bulk_enqueue.que` event; the inner enqueues are pass-throughs.
    module QueBulkClientPlugin
      def bulk_enqueue(*_args, job_options: {}, **_rest)
        # Under Active Job the enqueue is already recorded as an
        # `enqueue.active_job` event, so skip recording it again here.
        return super if Appsignal::Transaction.current? &&
          Appsignal::Transaction.current.job_enqueue_events_suppressed?

        Appsignal.instrument("bulk_enqueue.que", bulk_enqueue_title(job_options)) do
          # Flag the batch so the enqueues this block triggers pass through
          # without recording, without reading Que's internal bulk state.
          was_bulk = Thread.current[:appsignal_que_bulk_enqueue]
          Thread.current[:appsignal_que_bulk_enqueue] = true
          begin
            super
          ensure
            Thread.current[:appsignal_que_bulk_enqueue] = was_bulk
          end
        end
      end

      private

      # The batch's job class is known up front only from an explicit
      # `:job_class` or when `bulk_enqueue` is called on a concrete subclass;
      # called on `Que::Job` itself the class isn't known until the inner
      # enqueues run, so the title is left class-less.
      def bulk_enqueue_title(job_options)
        job_class = job_options[:job_class]
        job_class ||= name unless equal?(::Que::Job)
        return "bulk enqueue jobs" unless job_class

        "bulk enqueue #{job_class} jobs"
      end
    end
  end
end
