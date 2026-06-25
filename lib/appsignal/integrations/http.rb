# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module HttpIntegration
      def self.instrument(verb, uri, &block)
        uri_module = defined?(HTTP::URI) ? HTTP::URI : URI
        parsed_request_uri = uri.is_a?(URI) ? uri : uri_module.parse(uri.to_s)
        request_uri = "#{parsed_request_uri.scheme}://#{parsed_request_uri.host}"

        Appsignal.instrument(
          "request.http_rb",
          "#{verb.to_s.upcase} #{request_uri}",
          :opentelemetry_kind => :client,
          &block
        )
      end

      # `perform` is the single send chokepoint in both http5 and http6 (its
      # signature is identical), called once per request and once per redirect
      # hop. Instrumenting here keeps a single prepend module across versions and
      # gives each hop its own event with trace context injected into that hop's
      # outgoing request.
      def perform(req, options)
        HttpIntegration.instrument(req.verb, req.uri) do
          # Write trace context onto the outgoing request headers so the called
          # service joins this trace. No-op outside collector mode. `req.headers`
          # is the live outgoing header set and a valid carrier (it responds to
          # `[]=`).
          Appsignal::OpenTelemetry.inject_context(req.headers)
          super
        end
      end
    end
  end
end
