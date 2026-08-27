# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ActiveJobHook < Appsignal::Hooks::Hook
      register :active_job

      # This integration records the enqueue itself, as a producer event that
      # also injects trace context, and Active Job's own `enqueue.active_job`
      # notification fires nested inside it. Claim the event so that the
      # generic notification paths leave it alone.
      #
      # Claimed here, when this file is required, rather than in `install`.
      # `install` only runs when Active Job instrumentation is turned on, but
      # a customer who turns it off does not want to see the native
      # notification reported instead. This call does not touch any
      # `ActiveJob` constant, so it is safe to run even when the library is
      # not present.
      Appsignal::EventFormatter.register(
        "enqueue.active_job",
        Appsignal::EventFormatter::RecordedElsewhere
      )

      # Claimed for the same reason as the single enqueue above: this integration
      # records the batch itself, as one producer event, and Active Job's own
      # `enqueue_all.active_job` notification fires nested inside it.
      Appsignal::EventFormatter.register(
        "enqueue_all.active_job",
        Appsignal::EventFormatter::RecordedElsewhere
      )

      def self.version_7_1_or_higher?
        @version_7_1_or_higher ||=
          if dependencies_present?
            major = ::ActiveJob::VERSION::MAJOR
            minor = ::ActiveJob::VERSION::MINOR
            major > 7 || (major == 7 && minor >= 1)
          else
            false
          end
      end

      def self.dependencies_present?
        defined?(::ActiveJob)
      end

      def dependencies_present?
        self.class.dependencies_present? && Appsignal.config &&
          Appsignal.config[:instrument_active_job]
      end

      def install
        ActiveSupport.on_load(:active_job) do
          ::ActiveJob::Base
            .extend ::Appsignal::Hooks::ActiveJobHook::ActiveJobClassInstrumentation
          # Carry W3C trace context across the enqueue/perform boundary in
          # collector mode (no-ops otherwise). The patches are cheap and
          # mode-gated inside their method bodies, so install them unconditionally.
          ::ActiveJob::Base
            .prepend ::Appsignal::Hooks::ActiveJobHook::ActiveJobTraceContext

          # Active Job records a bulk enqueue through this method, which only
          # exists from version 7.1 on. Checking for the method, rather than for
          # the version, keeps us from defining one on a version that has no
          # bulk enqueue path to instrument.
          if ::ActiveJob.singleton_class.private_method_defined?(:instrument_enqueue_all)
            ::ActiveJob.singleton_class
              .prepend ::Appsignal::Hooks::ActiveJobHook::ActiveJobBulkEnqueueInstrumentation
          else
            # Without that method there is nothing to record the batch with, so
            # give the claim back and let Active Job's own notification through.
            # Claiming an event and then never recording it would report the
            # batch not at all, which is worse than reporting the notification we
            # set out to improve on.
            Appsignal::EventFormatter.unregister(
              "enqueue_all.active_job",
              Appsignal::EventFormatter::RecordedElsewhere
            )
          end

          next unless Appsignal::Hooks::ActiveJobHook.version_7_1_or_higher?

          # Only works on Active Job 7.1 and newer
          ::ActiveJob::Base.after_discard do |_job, exception|
            next unless Appsignal.config[:activejob_report_errors] == "discard"

            Appsignal::Transaction.current.set_error(exception)
          end
        end
      end

      # Records an `enqueue_all.active_job` event when a batch of jobs is
      # enqueued with `ActiveJob.perform_all_later`, so the batch shows up on the
      # active transaction's timeline as one event, and as one producer span in
      # collector mode.
      #
      # This wraps `instrument_enqueue_all` rather than `perform_all_later`, for
      # two reasons. It is the method that records the batch, so it is called
      # once for each queue adapter the batch spans, which is the same event
      # count as the native notification it replaces. And it runs inside
      # `perform_all_later`, after Active Job has split off the jobs it defers
      # until the database transaction commits, so each of those halves is
      # recorded when it is really enqueued.
      #
      # @!visibility private
      module ActiveJobBulkEnqueueInstrumentation
        private

        def instrument_enqueue_all(_queue_adapter, jobs)
          # When enqueue instrumentation is disabled, record nothing, the same as
          # the single-job path.
          return super if Appsignal.config && !Appsignal.config[:enable_job_enqueue_instrumentation]

          # Another enqueue integration is already recording this enqueue, so
          # don't record it a second time.
          if Appsignal::Transaction.current? &&
              Appsignal::Transaction.current.job_enqueue_events_suppressed?
            return super
          end

          Appsignal.instrument(
            "enqueue_all.active_job",
            bulk_enqueue_title(jobs),
            :opentelemetry_kind => :producer,
            :opentelemetry_scope => ["appsignal-ruby/active_job", Appsignal::VERSION]
          ) do
            Appsignal::Transaction.current.add_opentelemetry_attributes(
              Appsignal::OpenTelemetry::Messaging.enqueue_attributes(
                "active_job",
                :destination => bulk_enqueue_destination(jobs),
                :batch_size => jobs.size
              )
            )
            # A bulk enqueue does not go through `ActiveJob::Base#enqueue`, so
            # nothing has suppressed the adapter (Sidekiq, Resque, ...) yet, and
            # its own enqueue instrumentation would record an event for every job
            # in the batch. Suppress it so the batch is recorded once, as this
            # event.
            if Appsignal::Transaction.current?
              Appsignal::Transaction.current.suppress_job_enqueue_events { super }
            else
              super
            end
          end
        end

        # The batch's job class, when every job in it has the same one. Active
        # Job groups the jobs it enqueues by queue adapter rather than by class,
        # so a batch can mix classes, and then there is no one class to name.
        def bulk_enqueue_title(jobs)
          job_class = shared_across(jobs) { |job| job.class.name }
          return "bulk enqueue jobs" unless job_class

          "bulk enqueue #{job_class} jobs"
        end

        # The queue the batch went to, when every job in it is on the same one.
        # Grouping is by queue adapter and not by queue, so a batch can span
        # queues, and then there is no one queue to name as the destination.
        def bulk_enqueue_destination(jobs)
          shared_across(jobs, &:queue_name)
        end

        # The one value every job in the batch shares, or nil when they differ
        # or the batch is empty. Stops at the first job that disagrees, because
        # a batch is as large as the caller made it and a single mismatch is
        # enough to know.
        def shared_across(jobs)
          return if jobs.empty?

          first = yield(jobs.first)
          jobs.all? { |job| yield(job) == first } ? first : nil
        end
      end

      module ActiveJobClassInstrumentation
        def execute(job)
          enqueued_at = job["enqueued_at"]
          queue_start = Time.parse(enqueued_at) if enqueued_at
          queue_time =
            if queue_start
              time_now = Time.now.utc
              # Calculate queue time and store it as milliseconds
              (time_now - queue_start) * 1_000
            end

          job_status = nil
          has_wrapper_transaction = Appsignal::Transaction.current?
          transaction =
            if has_wrapper_transaction
              Appsignal::Transaction.current
            else
              # No standalone integration started before ActiveJob integration.
              # We don't have a separate integration for this QueueAdapter like
              # we do for Sidekiq.
              #
              # Read the trace context off the job so the transaction links back
              # to the enqueuer (no-op outside collector mode). Only here, in the
              # standalone branch: when a wrapper integration (e.g. Sidekiq)
              # created the transaction, it already extracted, so we must not
              # extract a second time.
              #
              # Prefer job_id from provider, instead of ActiveJob's internal ID.
              Appsignal::Transaction.create(
                Appsignal::Transaction::BACKGROUND_JOB,
                :opentelemetry_context => Appsignal::OpenTelemetry.extract_job_context(job),
                :opentelemetry_scope => ["appsignal-ruby/active_job", Appsignal::VERSION],
                :opentelemetry_kind => :consumer,
                :opentelemetry_relationship => :both
              )
            end

          unless has_wrapper_transaction
            # Describes this span as a job being performed. The messaging
            # system is what the trace timeline reads to recognize background
            # job work, and `active_job` is the value OpenTelemetry's own Active
            # Job instrumentation uses.
            #
            # Only set when this hook created the transaction. When an adapter
            # integration created it, that adapter already named itself, and its
            # answer is the more specific one.
            transaction.add_opentelemetry_attributes(
              Appsignal::OpenTelemetry::Messaging
                .perform_attributes("active_job", :destination => job["queue_name"])
            )
          end

          begin
            transaction.add_function_parameters_if_nil(job["arguments"])

            transaction_tags = ActiveJobHelpers.transaction_tags_for(job)
            transaction.add_tags(transaction_tags)

            transaction.set_action(ActiveJobHelpers.action_name(job))

            super
          rescue Exception => exception
            job_status = :failed
            transaction_set_error(transaction, exception)
            raise exception
          ensure
            if transaction
              # Present in Rails 6 and up
              transaction.set_queue_start((queue_start.to_f * 1_000).to_i) if queue_start

              unless has_wrapper_transaction
                # Only complete transaction if ActiveJob is not wrapped in
                # another supported integration, such as Sidekiq.
                Appsignal::Transaction.complete_current!
              end
            end

            metrics = ActiveJobHelpers.metrics_for(job)
            metrics.each do |(metric_name, tags)|
              if job_status
                ActiveJobHelpers.increment_counter metric_name, 1,
                  tags.merge(:status => job_status)
              end
              ActiveJobHelpers.increment_counter metric_name, 1,
                tags.merge(:status => :processed)
            end

            queue_name = job["queue_name"]
            if queue_time && queue_name
              ActiveJobHelpers.add_distribution_value(
                "queue_time",
                queue_time,
                :queue => queue_name
              )
            end
          end
        end

        private

        def transaction_set_error(transaction, exception)
          # Only report errors when the config option is set to "all".
          # To report errors on discard, see the `after_discard` callback.
          return unless Appsignal.config[:activejob_report_errors] == "all"

          transaction.set_error(exception)
        end
      end

      # Reads and writes W3C trace context on the ActiveJob enqueue/perform
      # boundary, wire-compatible with OpenTelemetry's ActiveJob instrumentation.
      # All of this no-ops outside collector mode.
      #
      # Context rides on the job under `__otel_headers`, the same carrier OTel
      # uses. Stock `serialize`/`deserialize` only carry a fixed key set, so --
      # like OTel -- we patch both plus an accessor to round-trip it. The on-wire
      # value is run through ActiveJob's argument serializer (an array of
      # `[key, value]` pairs), matching OTel byte-for-byte so an AppSignal- and an
      # OTel-instrumented service read each other's jobs.
      module ActiveJobTraceContext
        # Inject on enqueue from inside a producer event, so the job carries this
        # transaction's context and the perform later links back. Mirrors the
        # Sidekiq client middleware: an AppSignal event (a producer span in
        # collector mode), not a direct SDK span. `Appsignal.instrument` is a
        # transparent pass-through when there's no active transaction, and
        # `inject_context` no-ops outside collector mode.
        def enqueue(*, **)
          # When enqueue instrumentation is disabled, drop the trace context
          # along with the event. Without an enqueue event there is no producer
          # span, so the context we would write is that of whatever span is
          # current, such as the surrounding web request. The job that performs
          # later would then link back to a span that is not a producer.
          return super if Appsignal.config && !Appsignal.config[:enable_job_enqueue_instrumentation]

          # Another enqueue integration is already recording this enqueue, so
          # don't record it a second time.
          if Appsignal::Transaction.current? &&
              Appsignal::Transaction.current.job_enqueue_events_suppressed?
            return super
          end

          Appsignal.instrument(
            "enqueue.active_job",
            "enqueue #{self.class.name} job",
            :opentelemetry_kind => :producer,
            :opentelemetry_scope => ["appsignal-ruby/active_job", Appsignal::VERSION]
          ) do
            Appsignal::Transaction.current.add_opentelemetry_attributes(
              Appsignal::OpenTelemetry::Messaging
                .enqueue_attributes("active_job", :destination => queue_name)
            )
            Appsignal::OpenTelemetry.inject_context(__otel_headers)
            # Active Job enqueues through an adapter (Sidekiq, Resque, ...) that
            # has its own enqueue instrumentation. Suppress it so the enqueue is
            # recorded once, as this event, rather than as nested Active Job +
            # adapter events.
            if Appsignal::Transaction.current?
              Appsignal::Transaction.current.suppress_job_enqueue_events { super }
            else
              super
            end
          end
        end

        def serialize
          super.tap do |data|
            Appsignal::OpenTelemetry.if_started do
              next if __otel_headers.empty?

              data["__otel_headers"] = ::ActiveJob::Arguments.serialize(__otel_headers)
            end
          end
        end

        def deserialize(job_data)
          super
          serialized = job_data["__otel_headers"]
          @__otel_headers =
            serialized ? ::ActiveJob::Arguments.deserialize(serialized).to_h : {}
        end

        def __otel_headers
          @__otel_headers ||= {}
        end

        attr_writer :__otel_headers
      end

      module ActiveJobHelpers
        ACTION_MAILER_CLASSES = [
          "ActionMailer::DeliveryJob",
          "ActionMailer::Parameterized::DeliveryJob",
          "ActionMailer::MailDeliveryJob"
        ].freeze

        def self.action_name(job)
          case job["job_class"]
          when *ACTION_MAILER_CLASSES
            job["arguments"][0..1].join("#")
          else
            "#{job["job_class"]}#perform"
          end
        end

        # Returns an array of metrics with tags used to report the job metrics
        #
        # If job ONLY has a queue, it will return `queue_job_count` with tags.
        # If job has a queue AND priority, it will ALSO return
        # `queue_priority_job_count` with tags.
        #
        # @return [Array] Array of metrics with tags to report.
        def self.metrics_for(job)
          tags = { :queue => job["queue_name"] }
          metrics = [["queue_job_count", tags]]

          priority = job["priority"]
          if priority
            metrics << [
              "queue_priority_job_count",
              tags.merge(:priority => priority)
            ]
          end

          metrics
        end

        def self.transaction_tags_for(job)
          tags = {}

          queue = job["queue_name"]
          tags[:queue] = queue if queue

          priority = job["priority"]
          tags[:priority] = priority if priority

          executions = job["executions"]
          tags[:executions] = executions.to_i + 1 if executions

          job_id = job["job_id"]
          tags[:active_job_id] = job_id

          provider_job_id = job["provider_job_id"]
          tags[:provider_job_id] = provider_job_id if provider_job_id

          request_id = provider_job_id || job_id
          tags[:request_id] = request_id if request_id

          tags
        end

        def self.increment_counter(key, value, tags = {})
          Appsignal.increment_counter "active_job_#{key}", value, tags
        end

        def self.add_distribution_value(key, value, tags = {})
          Appsignal.add_distribution_value("active_job_#{key}", value, tags)
        end
      end
    end
  end
end
