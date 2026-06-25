# frozen_string_literal: true

module Appsignal
  module Integrations
    # Faraday middleware that writes trace context onto the outgoing request, so
    # the called service joins this trace. The `request.faraday` event recorded
    # by Faraday's own instrumentation middleware provides the span; this
    # middleware injects and, when that event is recorded, suppresses the
    # downstream HTTP client's own instrumentation.
    #
    # @!visibility private
    class FaradayMiddleware < ::Faraday::Middleware
      # `super(app)` passes only the app: Faraday 1's `Middleware#initialize`
      # takes the app alone, so forwarding our options hash to it would raise.
      def initialize(app, options = {})
        super(app)
        @suppress_downstream = options[:suppress_downstream]
      end

      def call(env)
        # Inject from whatever span is current. Faraday's instrumentation
        # middleware wraps this call in the `request.faraday` event, so its event
        # span is current and the written `traceparent` reflects the Faraday
        # client event. No-op outside collector mode. `env.request_headers` is the
        # live outgoing header set and a valid carrier (it responds to `[]=`).
        Appsignal::OpenTelemetry.inject_context(env.request_headers)

        # Faraday's default adapter is Net::HTTP, which AppSignal also
        # instruments. When the `request.faraday` event is recorded, suppress the
        # adapter's instrumentation so the request appears once (as the Faraday
        # event) rather than as nested Faraday + Net::HTTP client events.
        if @suppress_downstream && Appsignal::Transaction.current?
          Appsignal::Transaction.current.suppress_http_client_events { @app.call(env) }
        else
          @app.call(env)
        end
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
    #   Instrumentation so it runs inside that event's span. It also suppresses
    #   the downstream client when the Faraday event is recorded -- decided here,
    #   at build time, so it stays in sync with whether Instrumentation is added.
    #
    # @!visibility private
    module FaradayRackBuilderPatch
      def adapter(*)
        unless handlers.any? { |handler| handler.klass == FaradayMiddleware }
          # The `request.faraday` event needs ActiveSupport::Notifications, which
          # Faraday's instrumentation middleware references at build time.
          records_event = defined?(::ActiveSupport::Notifications) &&
            defined?(::Faraday::Request::Instrumentation)
          if records_event &&
              handlers.none? { |handler| handler.klass == ::Faraday::Request::Instrumentation }
            use(::Faraday::Request::Instrumentation)
          end
          use(FaradayMiddleware, { :suppress_downstream => records_event })
        end
        super
      end
    end
  end
end
