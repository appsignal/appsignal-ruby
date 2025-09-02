# frozen_string_literal: true

module Appsignal
  module Rack
    # @api private
    def self.rack_3_2_1_or_newer?
      return false unless ::Rack.respond_to?(:release)

      Gem::Version.new(::Rack.release) >= Gem::Version.new("3.2.1")
    end

    # Modified version of the {::Rack::Events} instrumentation
    # middleware.
    #
    # We recommend using this instead of {::Rack::Events}, as it
    # is compatible with streaming bodies when using Rack versions
    # before 3.2.0.
    #
    # We do not recommend using this middleware directly, instead
    # recommending the use of {EventMiddleware}, which is a
    # convenience wrapper around this middleware that includes
    # AppSignal's {EventHandler}.
    #
    # See the original implementation at:
    # https://github.com/rack/rack/blob/8d3d7857fcd9e5df057a6c22458bab35b3a19c12/lib/rack/events.rb

    if rack_3_2_1_or_newer?
      Events = ::Rack::Events
    else
      class Events < ::Rack::Events
        # A stub for {::Rack::Events::EventedBodyProxy}. It
        # allows the same initialization arguments, but
        # otherwise behaves identically to {::Rack::BodyProxy}.
        #
        # It does not implement `#each`, fixing an issue
        # where the evented body proxy would break
        # streaming responses by always responding to `#each`
        # even if the proxied body did not implement it.
        #
        # Because it ignores the handlers passed to it and
        # behaves like a normal body proxy, the `on_send`
        # event on the handlers is never called.
        class EventedBodyProxy < ::Rack::BodyProxy
          def initialize(body, _request, _response, _handlers, &block)
            super(body, &block)
          end
        end

        # The `call` method, exactly as implemented by {::Rack::Events},
        # but redefined here so that it uses our {EventedBodyProxy}
        # instead of the original {::Rack::Events::EventedBodyProxy}.
        #
        # This fixes streaming bodies, but it also means that the
        # `on_send` event on the handlers is never called.
        #
        # See the original implementation at:
        # https://github.com/rack/rack/blob/8d3d7857fcd9e5df057a6c22458bab35b3a19c12/lib/rack/events.rb#L111-L129
        def call(env)
          request = make_request env
          on_start request, nil

          begin
            status, headers, body = @app.call request.env
            response = make_response status, headers, body
            on_commit request, response
          rescue StandardError => e
            on_error request, response, e
            on_finish request, response
            raise
          end

          body = EventedBodyProxy.new(body, request, response, @handlers) do
            on_finish request, response
          end
          [response.status, response.headers, body]
        end
      end
    end

    # Instrumentation middleware using Rack's Events module.
    #
    # A convenience wrapper around our {Events} middleware,
    # modified to be compatible with streaming bodies,
    # that automatically includes AppSignal's {EventHandler}.
    #
    # We recommend using this in combination with the
    # {InstrumentationMiddleware}.
    #
    # This middleware will report the response status code as the
    # `response_status` tag on the sample. It will also report the response
    # status as the `response_status` metric.
    #
    # This middleware will ensure the AppSignal transaction is always completed
    # for every request.
    #
    # @example Add EventMiddleware to a Rack app
    #   # Add this middleware as the first middleware of an app
    #   use Appsignal::Rack::EventMiddleware
    #
    #   # Then add the InstrumentationMiddleware
    #   use Appsignal::Rack::InstrumentationMiddleware
    #
    # @see https://docs.appsignal.com/ruby/integrations/rack.html
    #   Rack integration documentation.
    # @api public
    class EventMiddleware < Events
      def initialize(app)
        super(app, [Appsignal::Rack::EventHandler.new.tap do |handler|
          handler.using_appsignal_event_middleware = true
        end])
      end
    end
  end
end
