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
          :opentelemetry_scope => ["appsignal-ruby-faraday", Appsignal::VERSION]
        ) do
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
          if Appsignal::Transaction.current?
            Appsignal::Transaction.current.suppress_http_client_events { @app.call(env) }
          else
            @app.call(env)
          end
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
