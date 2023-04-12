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
        instrumenter = ::ActiveSupport::Notifications::Instrumenter
        parent_integration_module = Appsignal::Integrations::ActiveSupportNotificationsIntegration
        if instrumenter.method_defined?(:start) && instrumenter.method_defined?(:finish)
          install_module(parent_integration_module::StartFinishIntegration)
        else
          install_module(parent_integration_module::InstrumentIntegration)
        end

        return unless instrumenter.method_defined?(:finish_with_state)

        install_module(parent_integration_module::FinishStateIntegration)
      end

      def install_module(mod)
        ::ActiveSupport::Notifications::Instrumenter.send(:prepend, mod)
      end
    end
  end
end
