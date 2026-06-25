# frozen_string_literal: true

module Appsignal
  module Integrations
    # Faraday middleware that writes trace context onto the outgoing request, so
    # the called service joins this trace. The `request.faraday` event recorded
    # by Faraday's own instrumentation middleware provides the span; this
    # middleware only injects.
    #
    # @!visibility private
    class FaradayMiddleware < ::Faraday::Middleware
      def on_request(env)
        # Inject from whatever span is current. Faraday's instrumentation
        # middleware wraps this call in the `request.faraday` event, so its event
        # span is current and the written `traceparent` reflects the Faraday
        # client event. No-op outside collector mode. `env.request_headers` is the
        # live outgoing header set and a valid carrier (it responds to `[]=`).
        Appsignal::OpenTelemetry.inject_context(env.request_headers)
      end
    end

    # Prepended to `Faraday::RackBuilder#adapter`, the single point every
    # connection passes through as it finishes building its middleware stack.
    # Faraday has no global default middleware stack (unlike Excon), so patching
    # the build path is the only way to instrument every connection automatically.
    #
    # Just before the adapter (the innermost handler, where the request is sent)
    # it inserts:
    #
    # - `Faraday::Request::Instrumentation`, so the `request.faraday` event fires
    #   without the user adding it themselves -- but only when
    #   ActiveSupport::Notifications is loaded, since that middleware references it
    #   at build time. Skipped if the user already added it.
    # - `FaradayMiddleware`, which injects trace context. Added after
    #   Instrumentation so it runs inside that event's span.
    #
    # @!visibility private
    module FaradayRackBuilderPatch
      def adapter(*)
        unless handlers.any? { |handler| handler.klass == FaradayMiddleware }
          if defined?(::ActiveSupport::Notifications) &&
              defined?(::Faraday::Request::Instrumentation) &&
              handlers.none? { |handler| handler.klass == ::Faraday::Request::Instrumentation }
            use(::Faraday::Request::Instrumentation)
          end
          use(FaradayMiddleware)
        end
        super
      end
    end
  end
end
