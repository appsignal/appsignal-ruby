# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ActiveSupportNotificationsIntegration
      class << self
        BANG = "!"

        # Events a dedicated AppSignal integration already records, so the
        # generic notifications path must not record them a second time. The
        # ActiveJob hook owns `enqueue.active_job`: it wraps the enqueue in its
        # own event, and Rails' native notification fires nested inside it.
        SUPPRESSED_EVENT_NAMES = ["enqueue.active_job"].freeze

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
          name[0] != BANG && !SUPPRESSED_EVENT_NAMES.include?(name.to_s)
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
