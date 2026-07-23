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

      # Que has no header map, so context rides in the tags array. OTel writes
      # each header as a `"key:value"` tag; mirror that exact format.
      module TagSetter
        def self.set(carrier, key, value)
          carrier << "#{key}:#{value}"
        end
      end

      # Que rejects jobs with too many or too-long tags, so injected context
      # must stay within these or the enqueue would raise. Read the limits from
      # Que when available, with the documented defaults as a fallback.
      MAX_TAGS_COUNT =
        defined?(::Que::Job::MAXIMUM_TAGS_COUNT) ? ::Que::Job::MAXIMUM_TAGS_COUNT : 5
      MAX_TAG_LENGTH =
        defined?(::Que::Job::MAXIMUM_TAG_LENGTH) ? ::Que::Job::MAXIMUM_TAG_LENGTH : 100

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

      # Returns the tags array to enqueue the job with. In collector mode injects
      # the current context into a copy of the tags; keeps the result only if it
      # still fits Que's limits, otherwise returns the original tags unchanged --
      # we skip propagation rather than break the user's enqueue. Outside
      # collector mode returns the tags unchanged.
      def inject(tags)
        original = Array(tags)
        injected = Appsignal::OpenTelemetry.if_started do
          copy = original.dup
          ::OpenTelemetry.propagation.inject(copy, :setter => TagSetter)
          copy
        end
        return original if injected.nil? || !within_limits?(injected)

        injected
      end

      def within_limits?(tags)
        tags.length <= MAX_TAGS_COUNT && tags.all? { |tag| tag.length <= MAX_TAG_LENGTH }
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
            :opentelemetry_context => QueTraceContext.extract(local_attrs.dig(:data, :tags)),
            :opentelemetry_kind => :consumer,
            :opentelemetry_relationship => :both
          )

        begin
          Appsignal.instrument("perform_job.que") { super }
        rescue Exception => error
          transaction.set_error(error)
          raise error
        ensure
          transaction.set_action_if_nil("#{local_attrs[:job_class]}#run")
          transaction.add_function_parameters_if_nil do
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
    # Prepended to `Que::Job`'s singleton so it wraps enqueues. Records the
    # enqueue as an AppSignal event (a producer span in collector mode), and in
    # collector mode writes the current trace context onto the job's tags so the
    # job that later performs links back to it. Like all AppSignal events, the
    # enqueue only records when there's an active transaction; otherwise it's a
    # transparent pass-through.
    module QueClientPlugin
      def enqueue(*args, job_options: {}, **rest)
        # Inside a `bulk_enqueue` block the per-job enqueue must stay a
        # pass-through: tags come from `bulk_enqueue`'s own `job_options` (Que
        # raises if an inner enqueue passes them), and the batch's event and
        # propagation are recorded once by the `bulk_enqueue` wrapper.
        return super if Thread.current[:appsignal_que_bulk_enqueue]

        # Resolve the job class the way Que does: an explicit `:job_class`, else
        # the class `enqueue` was called on.
        title = "enqueue #{job_options[:job_class] || name} job"
        record_enqueue(job_options, "enqueue.que", title) do |merged|
          super(*args, :job_options => merged, **rest)
        end
      end

      private

      # Records the enqueue as a producer event and, in collector mode, injects
      # the current trace context into the job's tags so the job that later
      # performs links back. Yields the (possibly tag-augmented) `job_options` to
      # do the actual enqueue.
      def record_enqueue(job_options, event_name, title)
        # Under Active Job the enqueue is already recorded as an
        # `enqueue.active_job` event, so skip recording it again here. The trace
        # context is still injected so the performed job links back.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.job_enqueue_events_suppressed?
          return yield job_options_with_context(job_options)
        end

        Appsignal.instrument(event_name, title, :opentelemetry_kind => :producer) do
          yield job_options_with_context(job_options)
        end
      end

      # In collector mode, injects the current trace context into a copy of the
      # job's tags and returns the tag-augmented `job_options`; a no-op that
      # returns `job_options` unchanged outside collector mode.
      def job_options_with_context(job_options)
        tags = QueTraceContext.inject(job_options[:tags])
        tags.empty? ? job_options : job_options.merge(:tags => tags)
      end
    end

    # @!visibility private
    #
    # `bulk_enqueue` exists only on Que 2+, so this lives in its own module that
    # the hook prepends only when Que has the method -- otherwise we'd define a
    # `bulk_enqueue` on Que versions that have none. The whole batch shares one
    # `job_options`, so it records a single `bulk_enqueue.que` producer event and
    # the inner enqueues are pass-throughs.
    module QueBulkClientPlugin
      def bulk_enqueue(job_options: {}, **rest, &block)
        record_enqueue(job_options, "bulk_enqueue.que", bulk_enqueue_title(job_options)) do |merged|
          # Flag the batch so the enqueues this block triggers pass through
          # without recording, without reading Que's internal bulk state.
          was_bulk = Thread.current[:appsignal_que_bulk_enqueue]
          Thread.current[:appsignal_que_bulk_enqueue] = true
          begin
            super(:job_options => merged, **rest, &block)
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
