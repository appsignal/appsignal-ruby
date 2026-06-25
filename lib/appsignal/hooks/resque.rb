# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ResqueHook < Appsignal::Hooks::Hook
      register :resque

      def dependencies_present?
        defined?(::Resque)
      end

      def install
        require "appsignal/integrations/resque"
        Resque::Job.prepend Appsignal::Integrations::ResqueIntegration

        # Resque enqueues through the `Resque.push` singleton method, so prepend
        # onto its singleton class to write the trace context onto outgoing jobs.
        Resque.singleton_class.prepend Appsignal::Integrations::ResquePushIntegration
      end
    end
  end
end
