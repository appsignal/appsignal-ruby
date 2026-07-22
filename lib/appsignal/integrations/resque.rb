# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ResqueIntegration
      def perform
        # Read trace context off the job so the transaction links back to the
        # enqueuer. No-op outside collector mode.
        transaction = Appsignal::Transaction.create(
          Appsignal::Transaction::BACKGROUND_JOB,
          :opentelemetry_context => Appsignal::OpenTelemetry.extract_job_context(payload),
          :opentelemetry_kind => :consumer,
          :opentelemetry_relationship => :link
        )

        Appsignal.instrument "perform.resque" do
          super
        end
      rescue Exception => exception
        transaction.set_error(exception)
        raise exception
      ensure
        if transaction
          transaction.set_action_if_nil("#{payload["class"]}#perform")
          transaction.add_params_if_nil { ResqueHelpers.arguments(payload) }
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
          :opentelemetry_kind => :producer
        ) do
          Appsignal::OpenTelemetry.inject_context(item)
          super
        end
      end
    end

    # @!visibility private
    class ResqueHelpers
      def self.arguments(payload)
        case payload["class"]
        when "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"
          nil # Set in the ActiveJob integration
        else
          payload["args"]
        end
      end
    end
  end
end
