# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module NetHttpIntegration
      def request(request, body = nil, &block)
        # Skip when an outer HTTP client integration (Faraday) already records
        # this request, so it isn't instrumented twice.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.http_client_events_suppressed?
          return super
        end

        Appsignal.instrument(
          "request.net_http",
          "#{request.method} #{use_ssl? ? "https" : "http"}://#{request["host"] || address}",
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby-net_http", Appsignal::VERSION]
        ) do
          # Write trace context onto the outgoing request so the called service
          # joins this trace. No-op outside collector mode. The request object
          # is a valid carrier (it responds to `[]=`).
          Appsignal::OpenTelemetry.inject_context(request)
          super
        end
      end
    end
  end
end
