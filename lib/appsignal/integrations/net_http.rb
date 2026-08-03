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
          :opentelemetry_scope => ["appsignal-ruby/net_http", Appsignal::VERSION]
        ) do
          # Describes the span as an outgoing HTTP request. Together with the
          # CLIENT kind, this is what the trace timeline reads to recognize it
          # as one.
          #
          # The client's own `address` and `port` name the host being called.
          # The request's `path` is a request target, so it can carry a query
          # string, which the attribute builder cuts off.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::HttpClientRequest.attributes_for(
              :method => request.method,
              :scheme => use_ssl? ? "https" : "http",
              :host => address,
              :port => port,
              :path => request.path
            )
          )
          # Write trace context onto the outgoing request so the called service
          # joins this trace. No-op outside collector mode. The request object
          # is a valid carrier (it responds to `[]=`).
          Appsignal::OpenTelemetry.inject_context(request)
          # Describes the response on the same span, which the semantic
          # conventions ask for whenever one was received. The event is still
          # open here, so it lands on the request's own span.
          super.tap do |response|
            Appsignal::Transaction.current.add_opentelemetry_attributes(
              Appsignal::OpenTelemetry::HttpResponse.attributes_for(response&.code)
            )
          end
        end
      end
    end
  end
end
