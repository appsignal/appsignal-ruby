# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Builds the OpenTelemetry attributes that describe a messaging operation,
    # which for AppSignal means a background job being enqueued or performed.
    #
    # The semantic conventions ask for the messaging system, the name of the
    # operation, and the kind of operation it was. The name is the job library's
    # own word for what happened. The kind is one of the five values the
    # conventions define, and AppSignal only ever produces two of them:
    # enqueuing a job sends a message, and performing one processes it.
    #
    # They also ask for the destination of the message, which for a job library
    # is the queue it is on, and for how many messages a span covers when it
    # covers a batch of them.
    #
    # The system is the only part that differs per job library, so each
    # integration passes its own.
    module Messaging
      SYSTEM_ATTRIBUTE = "messaging.system"
      OPERATION_NAME_ATTRIBUTE = "messaging.operation.name"
      OPERATION_TYPE_ATTRIBUTE = "messaging.operation.type"
      DESTINATION_ATTRIBUTE = "messaging.destination.name"
      BATCH_COUNT_ATTRIBUTE = "messaging.batch.message_count"

      # The operations AppSignal records, and the kind of operation the
      # conventions class each of them as.
      ENQUEUE = "enqueue"
      PERFORM = "perform"
      OPERATION_TYPES = {
        ENQUEUE => "send",
        PERFORM => "process"
      }.freeze

      class << self
        # The attributes describing a job being enqueued, as a Hash to pass to
        # `add_opentelemetry_attributes`.
        def enqueue_attributes(system, destination: nil, batch_size: nil)
          attributes_for(system, ENQUEUE, destination, batch_size)
        end

        # The attributes describing a job being performed, as a Hash to pass to
        # `add_opentelemetry_attributes`.
        def perform_attributes(system, destination: nil, batch_size: nil)
          attributes_for(system, PERFORM, destination, batch_size)
        end

        private

        def attributes_for(system, operation, destination, batch_size)
          {
            SYSTEM_ATTRIBUTE => system,
            OPERATION_NAME_ATTRIBUTE => operation,
            OPERATION_TYPE_ATTRIBUTE => OPERATION_TYPES.fetch(operation),
            DESTINATION_ATTRIBUTE => destination_name(destination),
            BATCH_COUNT_ATTRIBUTE => batch_count(batch_size)
          }.compact
        end

        # The queue the job is on, which the conventions call the destination of
        # the message. A job whose queue we cannot name is described without it.
        def destination_name(destination)
          name = destination.to_s
          name unless name.empty?
        end

        # How many messages the span covers. The conventions ask for this only
        # when a span describes a batch, and say it must not be set on a span
        # that describes a single message.
        def batch_count(batch_size)
          return unless batch_size

          count = batch_size.to_i
          count if count.positive?
        end
      end
    end
  end
end
