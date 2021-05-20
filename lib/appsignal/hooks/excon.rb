# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ExconHook < Appsignal::Hooks::Hook
      register :excon

      def dependencies_present?
        Appsignal.config && defined?(::Excon)
      end

      def install
        require "appsignal/integrations/excon"
        ::Excon.defaults[:instrumentor] = Appsignal::Integrations::ExconIntegration
      end
    end
  end
end
