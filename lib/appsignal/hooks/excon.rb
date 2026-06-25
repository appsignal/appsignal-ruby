# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ExconHook < Appsignal::Hooks::Hook
      register :excon

      def dependencies_present?
        Appsignal.config && defined?(::Excon)
      end

      def install
        require "appsignal/integrations/excon"
        require "appsignal/integrations/excon/appsignal_middleware"
        ::Excon.defaults[:instrumentor] = Appsignal::Integrations::ExconIntegration
        ::Excon.defaults[:middlewares] =
          ::Excon.defaults[:middlewares] + [Appsignal::Integrations::ExconMiddleware]
      end
    end
  end
end
