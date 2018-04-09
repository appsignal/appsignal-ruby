module Appsignal
  class Hooks
    # @api private
    class WebmachineHook < Appsignal::Hooks::Hook
      def dependencies_present?
        defined?(::Webmachine)
      end

      def install
        require "appsignal/integrations/webmachine"
        ::Webmachine::Decision::FSM.class_eval do
          include Appsignal::Integrations::WebmachinePlugin::FSM
          alias run_without_appsignal run
          alias run run_with_appsignal
          alias handle_exceptions_without_appsignal handle_exceptions
          alias handle_exceptions handle_exceptions_with_appsignal
        end
      end
    end
  end
end

Appsignal::Hooks.register(:webmachine, Appsignal::Hooks::WebmachineHook)
