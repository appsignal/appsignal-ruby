# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module ActiveJob
      # Active Job reports the job it is running as a `perform.active_job`
      # notification. The job's own transaction already carries its title, so
      # this formatter only describes the event as the work of performing a
      # job.
      class PerformFormatter < Appsignal::EventFormatter
        PERFORM_ATTRIBUTES =
          Appsignal::OpenTelemetry::Messaging.perform_attributes("active_job").freeze

        def opentelemetry_attributes(payload)
          PERFORM_ATTRIBUTES.merge(
            { "messaging.destination.name" => queue_name(payload) }.compact
          )
        end

        # The queue the job being performed is on, which the notification
        # carries as the job itself.
        def queue_name(payload)
          job = payload[:job]
          job.queue_name if job.respond_to?(:queue_name)
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "perform.active_job",
  Appsignal::EventFormatter::ActiveJob::PerformFormatter
)
