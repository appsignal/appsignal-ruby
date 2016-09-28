module Appsignal
  class Hooks
    class ActiveSupportNotificationsHook < Appsignal::Hooks::Hook
      register :active_support_notifications

      BANG = '!'.freeze

      def dependencies_present?
        defined?(::ActiveSupport::Notifications::Instrumenter)
      end

      def install
        ::ActiveSupport::Notifications::Instrumenter.class_eval do
          alias instrument_without_appsignal instrument

          def instrument(name, payload={}, &block)
            # Events that start with a bang are internal to Rails
            instrument_this = name[0] != BANG

            if instrument_this
              transaction = Appsignal::Transaction.current
              transaction.start_event
            end

            return_value = instrument_without_appsignal(name, payload, &block)

            if instrument_this
              title, body, body_format = Appsignal::EventFormatter.format(name, payload)
              transaction.finish_event(
                name,
                title,
                body,
                body_format
              )
            end

            return_value
          end
        end
      end
    end
  end
end
