# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ResqueHook < Appsignal::Hooks::Hook
      register :resque

      def dependencies_present?
        defined?(::Resque)
      end

      def install
        require "appsignal/integrations/resque"
        Resque::Job.prepend Appsignal::Integrations::ResqueIntegration
      end
    end
  end
end
