# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ActiveSupportNotificationsIntegration
      class << self
        BANG = "!"

        # ActiveSupport::Notifications events whose span represents an outgoing
        # call to a datastore, so they carry CLIENT kind in collector mode (to
        # match the dedicated DB integrations). Kept deliberately narrow:
        # `start_event` runs for every instrumented Rails event and span kind is
        # immutable, so only genuine client calls belong here. Object
        # instantiation (`instantiation.active_record`) is not a client call.
        CLIENT_EVENT_NAMES = ["sql.active_record"].freeze

        # Events a dedicated AppSignal integration already records with richer
        # semantics, so the generic notifications path must not record them a
        # second time. The ActiveJob hook owns `enqueue.active_job`: it wraps the
        # enqueue in a producer event that also injects trace context, and the
        # native notification fires nested inside it.
        SUPPRESSED_EVENT_NAMES = ["enqueue.active_job"].freeze

        def start_event(name)
          return unless record_event?(name)

          Appsignal::Transaction.current.start_event(
            :opentelemetry_kind => CLIENT_EVENT_NAMES.include?(name.to_s) ? :client : nil
          )
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
        # are recorded elsewhere. Both `start_event` and `finish_event` gate on
        # this so the event stack stays balanced.
        def record_event?(name)
          name = name.to_s
          name[0] != BANG && !SUPPRESSED_EVENT_NAMES.include?(name)
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
