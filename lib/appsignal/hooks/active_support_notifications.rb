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
    end
  end
end
