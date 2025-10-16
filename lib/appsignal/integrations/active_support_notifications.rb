# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ActiveSupportNotificationsIntegration
      BANG = "!"

      module InstrumentIntegration
        def instrument(name, payload = {}, &block)
          # Events that start with a bang are internal to Rails
          instrument_this = name[0] != ActiveSupportNotificationsIntegration::BANG

          Appsignal::Transaction.current.start_event if instrument_this

          super
        ensure
          if instrument_this
            title, body, body_format = Appsignal::EventFormatter.format(name, payload)
            Appsignal::Transaction.current.finish_event(
              name.to_s,
              title,
              body,
              body_format
            )
          end
        end
      end

      module StartFinishIntegration
        def start(name, payload = {})
          # Events that start with a bang are internal to Rails
          instrument_this = name[0] != ActiveSupportNotificationsIntegration::BANG

          Appsignal::Transaction.current.start_event if instrument_this

          super
        end

        def finish(name, payload = {})
          # Events that start with a bang are internal to Rails
          instrument_this = name[0] != ActiveSupportNotificationsIntegration::BANG

          if instrument_this
            title, body, body_format = Appsignal::EventFormatter.format(name, payload)
            Appsignal::Transaction.current.finish_event(
              name.to_s,
              title,
              body,
              body_format
            )
          end

          super
        end
      end

      module StartFinishHandlerIntegration
        def start
          instrument_this = @name[0] != ActiveSupportNotificationsIntegration::BANG

          Appsignal::Transaction.current.start_event if instrument_this
          super
        end

        def finish_with_values(name, id, payload = {})
          # Events that start with a bang are internal to Rails
          instrument_this = name[0] != ActiveSupportNotificationsIntegration::BANG

          if instrument_this
            title, body, body_format = Appsignal::EventFormatter.format(name, payload)
            Appsignal::Transaction.current.finish_event(
              name.to_s,
              title,
              body,
              body_format
            )
          end

          super
        end
      end

      module FinishStateIntegration
        def finish_with_state(listeners_state, name, payload = {})
          # Events that start with a bang are internal to Rails
          instrument_this = name[0] != ActiveSupportNotificationsIntegration::BANG

          if instrument_this
            title, body, body_format = Appsignal::EventFormatter.format(name, payload)
            Appsignal::Transaction.current.finish_event(
              name.to_s,
              title,
              body,
              body_format
            )
          end

          super
        end
      end

      # Rails 8.1+ introduced NullHandle as a performance optimization.
      # This integration only instruments when NullHandle is being used
      # (i.e., when there are no other subscribers).
      module NullHandleAwareInstrumentIntegration
        def instrument(name, payload = {}, &block)
          handle = build_handle(name, payload)

          # Only instrument if NullHandle is being used.
          # If Handle is being used, StartFinishHandlerIntegration will handle it.
          if defined?(::ActiveSupport::Notifications::Fanout::NullHandle) &&
              handle == ::ActiveSupport::Notifications::Fanout::NullHandle
            instrument_this = name[0] != ActiveSupportNotificationsIntegration::BANG

            Appsignal::Transaction.current.start_event if instrument_this

            begin
              super
            ensure
              if instrument_this
                title, body, body_format = Appsignal::EventFormatter.format(name, payload)
                Appsignal::Transaction.current.finish_event(
                  name.to_s,
                  title,
                  body,
                  body_format
                )
              end
            end
          else
            # Regular Handle case: let StartFinishHandlerIntegration handle it
            super
          end
        end
      end
    end
  end
end
