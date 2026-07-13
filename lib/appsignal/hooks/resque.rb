# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ResqueHook < Appsignal::Hooks::Hook
      register :resque

      def dependencies_present?
        defined?(::Resque) && Appsignal.config && Appsignal.config[:instrument_resque]
      end

      def install
        require "appsignal/integrations/resque"
        Resque::Job.prepend Appsignal::Integrations::ResqueIntegration

        # Resque enqueues through the `Resque.push` singleton method, so prepend
        # onto its singleton class to record the enqueue event.
        Resque.singleton_class.prepend Appsignal::Integrations::ResquePushIntegration
      end
    end
  end
end
