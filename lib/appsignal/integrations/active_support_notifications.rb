# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ActiveSupportNotificationsIntegration
      class << self
        BANG = "!"

        # Events a dedicated AppSignal integration already records, so the
        # generic notifications path must not record them a second time. The
        # ActiveJob hook owns `enqueue.active_job` and `enqueue_all.active_job`.
        # It records its own event for a single enqueue, and one event for a
        # whole batch, with Rails' native notification nested inside. The
        # Faraday integration owns `request.faraday`.
        SUPPRESSED_EVENT_NAMES = [
          "enqueue.active_job",
          "enqueue_all.active_job",
          "request.faraday"
        ].freeze

        # The events suppressed right now. Starts from the list above, which is
        # what an integration claims when it loads, and an integration that
        # turns out to be unable to record one of them for itself takes it back
        # off, so Rails' own notification is recorded rather than nothing at all.
        def suppressed_event_names
          @suppressed_event_names ||= SUPPRESSED_EVENT_NAMES.dup
        end

        # Stop suppressing an event, because the integration that claimed it
        # cannot record it after all.
        def unsuppress_event(name)
          suppressed_event_names.delete(name.to_s)
        end

        # @!visibility private
        #
        # Restores the claimed events. Only used to keep test runs isolated.
        def reset_suppressed_events!
          @suppressed_event_names = nil
        end

        def start_event(name)
          return unless record_event?(name)

          Appsignal::Transaction.current.start_event
        end

        def finish_event(name, payload = {})
          return unless record_event?(name)

          title, body, body_format = Appsignal::EventFormatter.format(name, payload)
          Appsignal::Transaction.current.finish_event(
            name.to_s,
            title,
            body,
            body_format
          )
        end

        # Events starting with a bang are internal to Rails; suppressed events
        # are recorded by a dedicated integration instead. Both `start_event`
        # and `finish_event` gate on this so the event stack stays balanced.
        def record_event?(name)
          name = name.to_s
          name[0] != BANG && !suppressed_event_names.include?(name)
        end
      end

      module InstrumentIntegration
        def instrument(name, payload = {}, &block)
          ActiveSupportNotificationsIntegration.start_event(name)
          super
        ensure
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
        end
      end

      module StartFinishIntegration
        def start(name, payload = {})
          ActiveSupportNotificationsIntegration.start_event(name)
          super
        end

        def finish(name, payload = {})
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
          super
        end
      end

      module StartFinishHandlerIntegration
        def start
          ActiveSupportNotificationsIntegration.start_event(@name)
          super
        end

        def finish_with_values(name, id, payload = {})
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
          super
        end
      end

      class NullHandleIntegration
        def initialize(name, _id, payload)
          @name = name
          @payload = payload
        end

        def start
          ActiveSupportNotificationsIntegration.start_event(@name)
        end

        def finish
          finish_with_values(@name, nil, @payload)
        end

        def finish_with_values(name, _id, payload)
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
        end
      end

      module BuildHandleFanoutIntegration
        def build_handle(name, id, payload)
          handle = super

          if handle == ::ActiveSupport::Notifications::Fanout::NullHandle
            NullHandleIntegration.new(name, id, payload)
          else
            handle
          end
        end
      end

      module FinishStateIntegration
        def finish_with_state(listeners_state, name, payload = {})
          ActiveSupportNotificationsIntegration.finish_event(name, payload)
          super
        end
      end
    end
  end
end
