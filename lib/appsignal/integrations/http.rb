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

      # The event is recorded at the request boundary, so a redirected request
      # stays a single `request.http_rb` event spanning every hop. That boundary
      # lives in more than one place: a bare request runs through
      # `HTTP::Client#request`, but in http6 a chained request (`.follow`,
      # `.headers`, `.timeout`, ...) runs through `HTTP::Session#request`
      # instead, which never touches `Client#request`. The hook prepends one of
      # these onto each. `Client#request` takes positional options in http5 and
      # keyword options in http6; `Session#request` (http6 only) takes keyword
      # options.
      module HashOptions
        def request(verb, uri, opts = {})
          HttpIntegration.instrument(verb, uri) { super }
        end
      end

      module KeywordOptions
        def request(verb, uri, **opts)
          HttpIntegration.instrument(verb, uri) { super }
        end
      end

      # Trace context has to ride on each outgoing hop's headers, so it's
      # injected at `HTTP::Client#perform` -- the single send chokepoint in both
      # http5 and http6, called once per request and once per redirect hop --
      # where the live request headers are reachable. The event stays at the
      # request boundary above, so a redirected request is still a single event;
      # this only propagates context, and every hop carries it. No-op outside
      # collector mode. `req.headers` is the live outgoing header set and a valid
      # carrier (it responds to `[]=`).
      module ContextInjection
        def perform(req, options)
          Appsignal::OpenTelemetry.inject_context(req.headers)
          super
        end
      end
    end
  end
end
