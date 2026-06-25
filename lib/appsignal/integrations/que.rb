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
    # Prepended to `Que::Job`'s singleton so it wraps enqueues. Records the
    # enqueue as an AppSignal event (a producer span in collector mode), and in
    # collector mode writes the current trace context onto the job's tags so the
    # job that later performs links back to it. Like all AppSignal events, the
    # enqueue only records when there's an active transaction; otherwise it's a
    # transparent pass-through.
    module QueClientPlugin
      def enqueue(*args, job_options: {}, **rest)
        Appsignal.instrument("enqueue.que", :opentelemetry_kind => :producer) do
          tags = QueTraceContext.inject(job_options[:tags])
          merged = tags.empty? ? job_options : job_options.merge(:tags => tags)
          super(*args, :job_options => merged, **rest)
        end
      end
    end
  end
end
