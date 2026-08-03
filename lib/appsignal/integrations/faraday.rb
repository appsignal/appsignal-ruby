# frozen_string_literal: true

module Appsignal
  module Integrations
    # Faraday middleware that records each request as a `request.faraday` client
    # event, writes trace context onto the outgoing request so the called service
    # joins this trace, and suppresses the downstream HTTP client's own
    # instrumentation, so the request is recorded once rather than as nested
    # Faraday + Net::HTTP (or Excon) client events.
    #
    # @!visibility private
    class FaradayMiddleware < ::Faraday::Middleware
      def call(env)
        http_method = env[:method].to_s.upcase
        uri = env[:url]
        # Title only, no body: the path is left out so the event matches
        # Net::HTTP's (scheme and host only), keeping paths out of event titles.
        Appsignal.instrument(
          "request.faraday",
          "#{http_method} #{uri.scheme}://#{uri.host}",
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby/faraday", Appsignal::VERSION]
        ) do
          # Describes the span as an outgoing HTTP request. Together with the
          # CLIENT kind, this is what the trace timeline reads to recognize it
          # as one.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::HttpClientRequest.attributes_for(
              :method => env[:method],
              :scheme => uri.scheme,
              :host => uri.host,
              :port => uri.port,
              :path => uri.path
            )
          )
          # Write trace context onto the outgoing request so the called service
          # joins this trace. Injected inside the instrument block, so the written
          # `traceparent` reflects the Faraday client event's span. No-op outside
          # collector mode. `env.request_headers` is the live outgoing header set
          # and a valid carrier (it responds to `[]=`).
          Appsignal::OpenTelemetry.inject_context(env.request_headers)

          # Faraday's default adapter is Net::HTTP, which AppSignal also
          # instruments. Suppress the adapter's own instrumentation so the
          # request appears once (as the Faraday event) rather than as nested
          # Faraday + Net::HTTP client events.
          response =
            if Appsignal::Transaction.current?
              Appsignal::Transaction.current.suppress_http_client_events { @app.call(env) }
            else
              @app.call(env)
            end

          # Describes the response on the same span, which the semantic
          # conventions ask for whenever one was received. The event is still
          # open here, so it lands on the request's own span. The status is read
          # off the environment rather than the returned response, because an
          # adapter fills the response in later than it fills in the environment.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::HttpResponse.attributes_for(env[:status])
          )

          response
        end
      end
    end

    # Prepended to `Faraday::RackBuilder#adapter`, the single point every
    # connection passes through as it finishes building its middleware stack.
    # Faraday has no global default middleware stack (unlike Excon), so patching
    # the build path is the only way to instrument every connection automatically.
    #
    # Just before the adapter (the innermost handler, where the request is sent)
    # it inserts `FaradayMiddleware`, which records the `request.faraday` event,
    # injects trace context, and suppresses the downstream client. Skipped if it's
    # already present.
    #
    # @!visibility private
    module FaradayRackBuilderPatch
      def adapter(*)
        use(FaradayMiddleware) unless handlers.any? { |handler| handler.klass == FaradayMiddleware }
        super
      end
    end
  end
end
