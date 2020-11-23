# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ActiveSupportNotificationsHook < Appsignal::Hooks::Hook
      register :active_support_notifications

      BANG = "!".freeze

      def dependencies_present?
        defined?(::ActiveSupport::Notifications::Instrumenter)
      end

      def install
        ::ActiveSupport::Notifications.class_eval do
          def self.instrument(name, payload = {})
            # Don't check the notifier if any subscriber is listening:
            # AppSignal is listening
            instrumenter.instrument(name, payload) do
              yield payload if block_given?
            end
          end
        end

        instrumenter = ::ActiveSupport::Notifications::Instrumenter

        if instrumenter.method_defined?(:start) && instrumenter.method_defined?(:finish)
          install_start_finish
        else
          install_instrument
        end

        # rubocop:disable Style/GuardClause
        if instrumenter.method_defined?(:finish_with_state)
          install_finish_with_state
        end
      end

      def install_instrument
        ::ActiveSupport::Notifications::Instrumenter.class_eval do
          alias instrument_without_appsignal instrument

          def instrument(name, payload = {}, &block)
            # Events that start with a bang are internal to Rails
            instrument_this = name[0] != BANG

            Appsignal::Transaction.current.start_event if instrument_this

            instrument_without_appsignal(name, payload, &block)
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
      end

      def install_start_finish
        ::ActiveSupport::Notifications::Instrumenter.class_eval do
          alias start_without_appsignal start

          def start(name, payload = {})
            # Events that start with a bang are internal to Rails
            instrument_this = name[0] != BANG

            Appsignal::Transaction.current.start_event if instrument_this

            start_without_appsignal(name, payload)
          end

          alias finish_without_appsignal finish

          def finish(name, payload = {})
            # Events that start with a bang are internal to Rails
            instrument_this = name[0] != BANG

            if instrument_this
              title, body, body_format = Appsignal::EventFormatter.format(name, payload)
              Appsignal::Transaction.current.finish_event(
                name.to_s,
                title,
                body,
                body_format
              )
            end

            finish_without_appsignal(name, payload)
          end
        end
      end

      def install_finish_with_state
        ::ActiveSupport::Notifications::Instrumenter.class_eval do
          alias finish_with_state_without_appsignal finish_with_state

          def finish_with_state(listeners_state, name, payload = {})
            # Events that start with a bang are internal to Rails
            instrument_this = name[0] != BANG

            if instrument_this
              title, body, body_format = Appsignal::EventFormatter.format(name, payload)
              Appsignal::Transaction.current.finish_event(
                name.to_s,
                title,
                body,
                body_format
              )
            end

            finish_with_state_without_appsignal(listeners_state, name, payload)
          end
        end
      end
    end
  end
end
