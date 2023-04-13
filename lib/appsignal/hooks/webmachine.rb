# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class WebmachineHook < Appsignal::Hooks::Hook
      register :webmachine

      def dependencies_present?
        defined?(::Webmachine)
      end

      def install
        require "appsignal/integrations/webmachine"
        ::Webmachine::Decision::FSM.prepend Appsignal::Integrations::WebmachineIntegration
      end
    end
  end
end
