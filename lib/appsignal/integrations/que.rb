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

      # Marks a job as one of a batch enqueued by `bulk_enqueue`, so the worker
      # can tell the two enqueue paths apart. Que itself records nothing that
      # distinguishes them: both insert paths write the same columns, and the
      # job's `data` only ever holds its tags. So the enqueue side has to say so.
      #
      # This deliberately contains no colon. The trace context rides in the same
      # tags array as `"key:value"` strings, so a reader that splits tags on the
      # colon to rebuild the carrier drops this tag on its own. That keeps it out
      # of the carrier for us and for OpenTelemetry's own Que instrumentation.
      BULK_TAG = "appsignal.bulk_enqueue"

      # Que only has tags from version 1.0 on, and they are the only carrier its
      # enqueue API exposes. On Que 0.x there is nowhere to put the trace context
      # that survives to the worker, so propagation is skipped there. Writing the
      # context into the job's arguments instead would change the arguments the
      # job is called with, which breaks the job.
      TAGS_SUPPORTED = defined?(::Que::Job::MAXIMUM_TAGS_COUNT)

      # Read the incoming context off the job's tags. Splits each `"key:value"`
      # tag on the first colon back into a carrier hash, then extracts. Returns
      # an `OpenTelemetry::Context`, or `nil` outside collector mode and on Que
      # versions without tags.
      def extract(tags)
        return unless TAGS_SUPPORTED

        Appsignal::OpenTelemetry.if_started do
          carrier = Array(tags)
            .map { |tag| tag.split(":", 2) }
            .select { |pair| pair.size == 2 }
            .to_h
          ::OpenTelemetry.propagation.extract(carrier)
        end
      end

      # Returns the tags array to enqueue the job with. In collector mode that is
      # a copy with the current context injected, kept only if it still fits
      # Que's limits: propagation is skipped rather than break the enqueue.
      # Outside collector mode, and on Que versions without tags, the tags are
      # returned unchanged.
      #
      # Pass `bulk` for a `bulk_enqueue` batch, which adds the bulk marker too.
      # Both are kept or dropped together, because a batch missing its marker
      # would parent every job in it to the one producer span.
      def inject(tags, bulk: false)
        original = Array(tags)
        return original unless TAGS_SUPPORTED

        injected = Appsignal::OpenTelemetry.if_started do
          copy = original.dup
          ::OpenTelemetry.propagation.inject(copy, :setter => TagSetter)
          # The marker has nothing to link back to without a trace context, so
          # only add it when the context was actually injected. The propagator
          # writes nothing when there is no valid span to propagate.
          copy << BULK_TAG if bulk && copy.length > original.length
          copy
        end
        return original if injected.nil? || !within_limits?(injected)

        injected
      end

      # Whether the job being performed was enqueued as part of a batch, which
      # the enqueue side records by adding `BULK_TAG` to the job's tags.
      def bulk?(tags)
        Array(tags).include?(BULK_TAG)
      end

      # The class the Active Job adapter enqueues, with the serialized job data
      # as its only argument. Que records the name in the job's `job_class`, and
      # the name is fixed, because it is stored in every job record the adapter
      # has ever written.
      ACTIVE_JOB_WRAPPER = "ActiveJob::QueueAdapters::QueAdapter::JobWrapper"

      # The trace context to continue: the Active Job layer when this is an
      # Active Job job, the job's own tags otherwise. See `Appsignal::OpenTelemetry.extract_active_job_context`
      # for why that layer wins.
      # Que's tags are a carrier with a hard limit: five per job, shared with
      # whatever the user puts there.
      def extract_context(job_data, tags)
        Appsignal::OpenTelemetry.extract_active_job_context(job_data) || extract(tags)
      end

      # The serialized Active Job job data inside a Que job, or nil when this is
      # not an Active Job job.
      #
      # Que reads a job's arguments out of JSONB with symbol keys and only turns
      # them back into strings on the way into Active Job, so they are
      # stringified here too. Only the outer keys need it: the headers below them
      # are an array of pairs of strings, which Que leaves alone.
      def active_job_data(attrs)
        return unless attrs[:job_class] == ACTIVE_JOB_WRAPPER

        job_data = Array(attrs[:args]).first
        job_data.transform_keys(&:to_s) if job_data.is_a?(Hash)
      end

      def within_limits?(tags)
        tags.length <= MAX_TAGS_COUNT && tags.all? { |tag| tag.length <= MAX_TAG_LENGTH }
      end
    end

    # @!visibility private
    module QuePlugin
      def _run(*args)
        local_attrs = respond_to?(:que_attrs) ? que_attrs : attrs
        tags = local_attrs.dig(:data, :tags)

        job_data = QueTraceContext.active_job_data(local_attrs)
        # A Que batch says so with a tag, and an Active Job batch says so in the
        # job data, so both have to be asked. See
        # `Appsignal::OpenTelemetry.active_job_relationship` for why a batch
        # links back rather than parenting under the span that enqueued it.
        relationship =
          if QueTraceContext.bulk?(tags)
            :link
          else
            Appsignal::OpenTelemetry.active_job_relationship(job_data)
          end

        # Read the incoming trace context off the job's tags so the transaction
        # links back to the enqueuer. No-op outside collector mode.
        transaction =
          Appsignal::Transaction.create(
            Appsignal::Transaction::BACKGROUND_JOB,
            :opentelemetry_context => QueTraceContext.extract_context(job_data, tags),
            :opentelemetry_scope => ["appsignal-ruby/que", Appsignal::VERSION],
            :opentelemetry_kind => :consumer,
            :opentelemetry_relationship => relationship
          )
        # Describes this span as a job being performed. The messaging system is
        # what the trace timeline reads to recognize background job work, and
        # `que` is the value OpenTelemetry's own Que instrumentation uses.
        transaction.add_opentelemetry_attributes(
          Appsignal::OpenTelemetry::Messaging
            .perform_attributes("que", :destination => local_attrs[:queue])
        )

        begin
          Appsignal.instrument(
            "perform_job.que",
            :opentelemetry_scope => ["appsignal-ruby/que", Appsignal::VERSION]
          ) do
            Appsignal::Transaction.current.add_opentelemetry_attributes(
              Appsignal::OpenTelemetry::Messaging
                .perform_attributes("que", :destination => local_attrs[:queue])
            )
            super
          end
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
      # The keyword arguments are captured into a single `kwargs` hash, rather
      # than declaring a `job_options:` keyword with a default, so that a
      # keyword the caller did not pass is never forwarded to Que. See
      # `forward_job_options` for why that matters.
      def enqueue(*args, **kwargs)
        # Inside a `bulk_enqueue` block the per-job enqueue must stay a
        # pass-through: tags come from `bulk_enqueue`'s own `job_options` (Que
        # raises if an inner enqueue passes them), and the batch's event and
        # propagation are recorded once by the `bulk_enqueue` wrapper.
        return super if Thread.current[:appsignal_que_bulk_enqueue]

        job_options = kwargs[:job_options] || {}

        # Resolve the job class the way Que does: an explicit `:job_class`, else
        # the class `enqueue` was called on.
        title = "enqueue #{job_options[:job_class] || name} job"
        record_enqueue(job_options, "enqueue.que", title) do |merged|
          super(*args, **forward_job_options(kwargs, merged))
        end
      end

      private

      # Builds the keyword arguments to enqueue the job with. Passes
      # `job_options` on to Que only when the caller passed it, or when the
      # trace context was injected into it. Adding a `job_options` keyword to a
      # call that did not have one breaks Que 0.x: it does not recognise the
      # keyword, so it stores it as an extra job argument, and the job then
      # fails because it is called with one argument too many.
      def forward_job_options(kwargs, job_options)
        return kwargs unless kwargs.key?(:job_options) || job_options.any?

        kwargs.merge(:job_options => job_options)
      end

      # Records the enqueue as a producer event and, in collector mode, injects
      # the current trace context into the job's tags so the job that later
      # performs links back. Yields the (possibly tag-augmented) `job_options` to
      # do the actual enqueue.
      def record_enqueue(job_options, event_name, title, bulk: false)
        # When enqueue instrumentation is disabled, drop the trace context along
        # with the event, so yield the job options untouched. Without an enqueue
        # event there is no producer span, so the context we would write is that
        # of whatever span is current, such as the surrounding web request. The
        # job that performs later would then link back to a span that is not a
        # producer.
        if Appsignal.config && !Appsignal.config[:enable_job_enqueue_instrumentation]
          return yield job_options
        end

        # Under Active Job the enqueue is already recorded as an
        # `enqueue.active_job` event, so skip recording it again here. The trace
        # context is still injected so the performed job links back.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.job_enqueue_events_suppressed?
          return yield job_options_with_context(job_options, :bulk => bulk)
        end

        Appsignal.instrument(
          event_name,
          title,
          :opentelemetry_kind => :producer,
          :opentelemetry_scope => ["appsignal-ruby/que", Appsignal::VERSION]
        ) do
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::Messaging
              .enqueue_attributes("que", :destination => job_options[:queue])
          )
          yield job_options_with_context(job_options, :bulk => bulk)
        end
      end

      # In collector mode, injects the current trace context into a copy of the
      # job's tags and returns the tag-augmented `job_options`; a no-op that
      # returns `job_options` unchanged outside collector mode.
      def job_options_with_context(job_options, bulk: false)
        tags = QueTraceContext.inject(job_options[:tags], :bulk => bulk)
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
        record_enqueue(
          job_options,
          "bulk_enqueue.que",
          bulk_enqueue_title(job_options),
          :bulk => true
        ) do |merged|
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
