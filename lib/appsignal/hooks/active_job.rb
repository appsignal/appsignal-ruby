# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ActiveJobHook < Appsignal::Hooks::Hook
      register :active_job

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
        self.class.dependencies_present?
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

          next unless Appsignal::Hooks::ActiveJobHook.version_7_1_or_higher?

          # Only works on Active Job 7.1 and newer
          ::ActiveJob::Base.after_discard do |_job, exception|
            next unless Appsignal.config[:activejob_report_errors] == "discard"

            Appsignal::Transaction.current.set_error(exception)
          end
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
                :opentelemetry_context => Appsignal::OpenTelemetry.extract_job_context(job)
              )
            end

          begin
            transaction.add_params_if_nil(job["arguments"])

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
        def enqueue(*)
          Appsignal.instrument("enqueue.active_job", :opentelemetry_kind => :producer) do
            Appsignal::OpenTelemetry.inject_context(__otel_headers)
            super
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
