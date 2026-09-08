# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ResqueIntegration
      def perform
        # Read trace context off the job so the transaction links back to the
        # enqueuer. No-op outside collector mode.
        job_data = ResqueHelpers.active_job_data(payload)
        transaction = Appsignal::Transaction.create(
          Appsignal::Transaction::BACKGROUND_JOB,
          :opentelemetry_context => ResqueHelpers.extract_context(payload, job_data),
          :opentelemetry_scope => ["appsignal-ruby/resque", Appsignal::VERSION],
          :opentelemetry_kind => :consumer,
          :opentelemetry_relationship =>
            Appsignal::OpenTelemetry.active_job_relationship(job_data)
        )
        # Describes this span as a job being performed. The messaging system is
        # what the trace timeline reads to recognize background job work, and
        # `resque` is the value OpenTelemetry's own Resque instrumentation uses.
        transaction.add_opentelemetry_attributes(
          Appsignal::OpenTelemetry::Messaging
            .perform_attributes("resque", :destination => queue)
        )

        Appsignal.instrument(
          "perform.resque",
          :opentelemetry_scope => ["appsignal-ruby/resque", Appsignal::VERSION]
        ) do
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::Messaging
              .perform_attributes("resque", :destination => queue)
          )
          super
        end
      rescue Exception => exception
        transaction.set_error(exception)
        raise exception
      ensure
        if transaction
          transaction.set_action_if_nil("#{payload["class"]}#perform")
          transaction.add_function_parameters_if_nil { ResqueHelpers.arguments(payload) }
          transaction.add_tags("queue" => queue)

          Appsignal::Transaction.complete_current!
        end
        Appsignal.stop("resque")
      end
    end

    # Wraps `Resque.push` to record an `enqueue.resque` event so the
    # enqueue shows up under the active transaction (both modes), and in
    # collector mode writes the trace context onto the job hash so the job that
    # later performs links back to it.
    #
    # Like all AppSignal events, this only records when there's an active
    # transaction (e.g. enqueuing from within a web request or another job).
    # An enqueue with no transaction is a transparent pass-through.
    #
    # @!visibility private
    module ResquePushIntegration
      def push(queue, item)
        # When enqueue instrumentation is disabled, drop the trace context along
        # with the event. Without an enqueue event there is no producer span, so
        # the context we would write is that of whatever span is current, such as
        # the surrounding web request. The job that performs later would then
        # link back to a span that is not a producer.
        return super if Appsignal.config && !Appsignal.config[:enable_job_enqueue_instrumentation]

        # Under Active Job the enqueue is already recorded as an
        # `enqueue.active_job` event, so skip recording it again here. The trace
        # context is still injected so the performed job links back.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.job_enqueue_events_suppressed?
          Appsignal::OpenTelemetry.inject_context(item)
          return super
        end

        Appsignal.instrument(
          "enqueue.resque",
          "enqueue #{item["class"]} job",
          :opentelemetry_kind => :producer,
          :opentelemetry_scope => ["appsignal-ruby/resque", Appsignal::VERSION]
        ) do
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::Messaging
              .enqueue_attributes("resque", :destination => queue)
          )
          Appsignal::OpenTelemetry.inject_context(item)
          super
        end
      end
    end

    # @!visibility private
    class ResqueHelpers
      # The class the Active Job adapter enqueues, with the serialized job data
      # as its only argument.
      ACTIVE_JOB_WRAPPER = "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"

      def self.arguments(payload)
        case payload["class"]
        when ACTIVE_JOB_WRAPPER
          nil # Set in the ActiveJob integration
        else
          payload["args"]
        end
      end

      # The serialized Active Job job data inside a Resque job, or nil when this
      # is not an Active Job job.
      def self.active_job_data(payload)
        return unless payload["class"] == ACTIVE_JOB_WRAPPER

        job_data = payload["args"]&.first
        job_data if job_data.is_a?(Hash)
      end

      # The trace context to continue: the Active Job layer when this is an
      # Active Job job, the Resque job itself otherwise. See `Appsignal::OpenTelemetry.extract_active_job_context`
      # for why that layer wins.
      def self.extract_context(payload, job_data)
        Appsignal::OpenTelemetry.extract_active_job_context(job_data) ||
          Appsignal::OpenTelemetry.extract_job_context(payload)
      end
    end
  end
end
