# frozen_string_literal: true

module Appsignal
  module Rack
    # @api public
    class GrapeMiddleware < Appsignal::Rack::AbstractMiddleware
      # @api private
      def initialize(app, options = {})
        options[:instrument_event_name] = "process_request.grape"
        options[:opentelemetry_scope] = ["appsignal-ruby/grape", Appsignal::VERSION]
        options[:report_errors] = lambda { |env| !env["grape.skip_appsignal_error"] }
        super
      end

      private

      def add_transaction_metadata_after(transaction, request)
        endpoint = request.env["api.endpoint"]
        request_method, klass, path = endpoint && endpoint_action(endpoint)
        unless path
          super
          return
        end

        transaction.set_action_if_nil("#{request_method}::#{klass}##{path}")

        super

        transaction.set_metadata("path", path)
      end

      # Returns the HTTP method, API class and path that make up the action
      # name, or nil when the endpoint does not describe a route.
      def endpoint_action(endpoint)
        options = endpoint.options
        return unless options

        if options.key?(:path)
          # Only Grape 3 and older populate `options[:path]`. Their route is
          # readable too, but its path is the full route template, so reading
          # it would rename the actions these applications already report.
          endpoint_action_from_options(endpoint, options)
        else
          # Grape 4 keeps these three in a value object behind a protected
          # reader, leaving the route as the only public source.
          endpoint_action_from_route(endpoint)
        end
      end

      def endpoint_action_from_options(endpoint, options)
        namespace = endpoint.namespace
        namespace = "" if namespace == "/"

        path = options[:path].first.to_s
        path = "/#{path}" if path[0] != "/"

        [
          options[:method].first.to_s.upcase,
          options[:for],
          "#{namespace}#{path}"
        ]
      end

      def endpoint_action_from_route(endpoint)
        route = endpoint.routes.first
        return unless route

        [route.request_method.to_s.upcase, endpoint.api, route.origin]
      end
    end
  end
end
