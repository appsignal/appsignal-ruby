# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ActiveSupportNotificationsHook < Appsignal::Hooks::Hook
      register :active_support_notifications

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

        require "appsignal/integrations/active_support_notifications"
        ::ActiveSupport::Notifications::Instrumenter.send(:prepend, Appsignal::Integrations::ActiveSupportNotificationsIntegration)
      end
    end
  end
end
