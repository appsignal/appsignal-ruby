# frozen_string_literal: true

module Appsignal
  module Integrations
    # Wraps Pgbus::ActiveJob::Executor#execute to create AppSignal transactions
    # for each job processed by Pgbus workers.
    #
    # @!visibility private
    module PgbusExecutorPlugin
      def execute(message, queue_name, source_queue: nil)
        job_status = nil
        payload = JSON.parse(message.message)
        job_class = payload["job_class"] || "unknown"
        action_name = "#{job_class}#perform"

        transaction =
          Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)
        transaction.set_action_if_nil(action_name)

        enqueued_at = payload["enqueued_at"]
        if enqueued_at
          queue_start = (Time.parse(enqueued_at).to_f * 1_000).to_i
          transaction.set_queue_start(queue_start)
        end

        Appsignal.instrument("perform_job.pgbus") do
          super
        end
      rescue Exception => exception # rubocop:disable Lint/RescueException
        job_status = :failed
        transaction.set_error(exception)
        raise exception
      ensure
        if transaction
          transaction.add_params_if_nil do
            { :arguments => payload["arguments"] }
          end
          transaction.add_tags(
            "queue" => queue_name,
            "job_class" => job_class,
            "provider_job_id" => payload["provider_job_id"],
            "active_job_id" => payload["job_id"],
            "request_id" => payload["provider_job_id"] || payload["job_id"],
            "attempts" => message.read_ct.to_i
          )

          Appsignal::Transaction.complete_current!

          if job_status
            increment_counter("queue_job_count", 1,
              :queue => queue_name, :status => job_status)
          end
          increment_counter("queue_job_count", 1,
            :queue => queue_name, :status => :processed)
        end
      end

      private

      def increment_counter(key, value, tags = {})
        Appsignal.increment_counter("pgbus_#{key}", value, tags)
      end
    end

    # Wraps Pgbus::Streams::Stream#broadcast to instrument stream broadcasts
    # with counters and timing distribution values.
    #
    # @!visibility private
    module PgbusStreamPlugin
      def broadcast(payload, visible_to: nil)
        Appsignal.instrument("broadcast.pgbus") do
          super
        end
      ensure
        Appsignal.increment_counter(
          "pgbus_stream_broadcast_count", 1,
          :stream => name
        )
      end
    end

    # Wraps Pgbus::EventBus::Handler#process to create AppSignal transactions
    # for each event handled by Pgbus consumers.
    #
    # @!visibility private
    module PgbusHandlerPlugin
      def process(message)
        raw = JSON.parse(message.message)
        event_id = raw["event_id"]
        routing_key = raw.dig("headers", "routing_key") || raw["routing_key"]
        action_name = "#{self.class.name}#handle"

        transaction =
          Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)
        transaction.set_action_if_nil(action_name)

        Appsignal.instrument("process_event.pgbus") do
          super
        end
      rescue Exception => exception # rubocop:disable Lint/RescueException
        transaction.set_error(exception)
        raise exception
      ensure
        if transaction
          transaction.add_params_if_nil { raw["payload"] }
          transaction.add_tags(
            "event_id" => event_id,
            "routing_key" => routing_key,
            "handler" => self.class.name
          )
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
