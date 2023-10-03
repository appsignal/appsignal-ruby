# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class DryMonitorHook < Appsignal::Hooks::Hook
      register :dry_monitor

      def dependencies_present?
        defined?(::Dry::Monitor::Notifications)
      end

      def install
        require "appsignal/integrations/dry_monitor"

        ::Dry::Monitor::Notifications.prepend(Appsignal::Integrations::DryMonitorIntegration)
      end
    end
  end
end
