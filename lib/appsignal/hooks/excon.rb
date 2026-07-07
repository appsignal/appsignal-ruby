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

        # Insert our middleware just before the Mock middleware (the innermost,
        # where the response is produced) so its `request_call` runs before the
        # request is sent -- and, being inside the Instrumentor middleware, while
        # our event span is current, so the injected `traceparent` reflects it.
        # Appending to the end would place it after Mock, which short-circuits
        # the request chain before reaching it.
        middlewares = ::Excon.defaults[:middlewares].dup
        return if middlewares.include?(Appsignal::Integrations::ExconMiddleware)

        index = middlewares.index(::Excon::Middleware::Mock) || middlewares.length
        middlewares.insert(index, Appsignal::Integrations::ExconMiddleware)
        ::Excon.defaults[:middlewares] = middlewares
      end
    end
  end
end
