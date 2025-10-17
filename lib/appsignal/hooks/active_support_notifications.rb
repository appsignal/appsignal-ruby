# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
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
        parent_integration_module = Appsignal::Integrations::ActiveSupportNotificationsIntegration

        if defined?(::ActiveSupport::Notifications::Fanout::Handle)
          install_module(
            parent_integration_module::StartFinishHandlerIntegration,
            ::ActiveSupport::Notifications::Fanout::Handle
          )

          # Rails 8.1+ optimization: when there are no subscribers, build_handle returns
          # NullHandle instead of Handle. We need to also hook into Instrumenter to
          # catch these cases.
          if defined?(::ActiveSupport::Notifications::Fanout::NullHandle)
            instrumenter = ::ActiveSupport::Notifications::Instrumenter
            install_module(
              parent_integration_module::NullHandleAwareInstrumentIntegration,
              instrumenter
            )
          end
        else
          instrumenter = ::ActiveSupport::Notifications::Instrumenter

          if instrumenter.method_defined?(:start) && instrumenter.method_defined?(:finish)
            install_module(parent_integration_module::StartFinishIntegration, instrumenter)
          else
            install_module(parent_integration_module::InstrumentIntegration, instrumenter)
          end

          return unless instrumenter.method_defined?(:finish_with_state)

          install_module(parent_integration_module::FinishStateIntegration, instrumenter)
        end
      end

      def install_module(mod, instrumenter)
        instrumenter.send(:prepend, mod)
      end
    end
  end
end
