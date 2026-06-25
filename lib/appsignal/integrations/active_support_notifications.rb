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

        def start_event(name)
          # Events that start with a bang are internal to Rails
          return if name[0] == BANG

          Appsignal::Transaction.current.start_event(
            :opentelemetry_kind => CLIENT_EVENT_NAMES.include?(name.to_s) ? :client : nil
          )
        end

        def finish_event(name, payload = {})
          # Events that start with a bang are internal to Rails
          instrument_this = name[0] != BANG
          return unless instrument_this

          title, body, body_format = Appsignal::EventFormatter.format(name, payload)
          Appsignal::Transaction.current.finish_event(
            name.to_s,
            title,
            body,
            body_format
          )
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
