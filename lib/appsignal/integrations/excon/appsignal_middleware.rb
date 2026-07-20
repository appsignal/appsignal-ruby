# frozen_string_literal: true

module Appsignal
  module Integrations
    # Excon middleware that writes trace context onto the outgoing request, so
    # the called service joins this trace. The existing Excon instrumentor
    # records the event span; this middleware only injects.
    #
    # @!visibility private
    class ExconMiddleware < ::Excon::Middleware::Base
      def request_call(datum)
        datum[:headers] ||= {}
        # Inject from whatever span is current. The instrumentor's event span is
        # active during the request, so the written `traceparent` reflects the
        # Excon client event. No-op outside collector mode.
        Appsignal::OpenTelemetry.inject_context(datum[:headers])
        super
      end
    end
  end
end
