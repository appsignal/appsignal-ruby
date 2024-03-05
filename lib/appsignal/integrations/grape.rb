# frozen_string_literal: true

module Appsignal
  # @todo Move to sub-namespace
  # @api private
  module Grape
    class GrapeInstrumentation < ::Appsignal::Rack::GenericInstrumentation
      def set_transaction_attributes_from_request(transaction, request)
        env = request.env

        request_method = request.request_method.to_s.upcase
        path = request.path # Path without namespaces
        endpoint = env["api.endpoint"]

        # Do not set error if "grape.skip_appsignal_error" is set to `true`.
        transaction.set_error(error) unless env["grape.skip_appsignal_error"]

        if endpoint&.options
          options = endpoint.options
          request_method = options[:method].first.to_s.upcase
          klass = options[:for]
          namespace = endpoint.namespace
          namespace = "" if namespace == "/"

          path = options[:path].first.to_s
          path = "/#{path}" if path[0] != "/"
          path = "#{namespace}#{path}"

          transaction.set_action_if_nil("#{request_method}::#{klass}##{path}")
        end

        transaction.set_http_or_background_queue_start
        transaction.set_metadata("path", path)
        transaction.set_metadata("method", request_method)
      end
    end

    # Grape middleware has a slightly different API than Rack middleware,
    # but nothing forbids us from embedding actual Rack middleware inside of it
    class Middleware < ::Grape::Middleware::Base
      def call(env)
        GrapeInstrumentation.new(app).call(env)
      end
    end
  end
end
