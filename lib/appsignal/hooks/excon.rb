# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ExconHook < Appsignal::Hooks::Hook
      register :excon

      def dependencies_present?
        Appsignal.config && defined?(::Excon) && Appsignal.config[:instrument_excon]
      end

      def install
        require "appsignal/integrations/excon"
        require "appsignal/integrations/excon/appsignal_middleware"
        # Instrument the request at the connection, rather than by registering
        # AppSignal as Excon's instrumentor. An instrumentor is told about a
        # request in pieces, none of which covers the wait for the response, and
        # there is only room for one of them, so registering ours would replace
        # any the application set up itself.
        ::Excon::Connection.prepend Appsignal::Integrations::ExconIntegration
        install_middleware

        Appsignal::Environment.report_enabled("excon")
      end

      private

      # Trace context is written onto the outgoing request by a middleware,
      # because that is where Excon exposes the request's headers.
      #
      # Insert it just before the Mock middleware, the innermost one, where the
      # response is produced. That way it runs before the request is sent.
      # Appending to the end would place it after Mock, which short-circuits the
      # chain before reaching it.
      def install_middleware
        middlewares = ::Excon.defaults[:middlewares].dup
        return if middlewares.include?(Appsignal::Integrations::ExconMiddleware)

        index = middlewares.index(::Excon::Middleware::Mock) || middlewares.length
        middlewares.insert(index, Appsignal::Integrations::ExconMiddleware)
        ::Excon.defaults[:middlewares] = middlewares
      end
    end
  end
end
