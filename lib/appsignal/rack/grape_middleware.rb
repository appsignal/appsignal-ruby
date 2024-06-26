# frozen_string_literal: true

module Appsignal
  module Rack
    # @api private
    class GrapeMiddleware < Appsignal::Rack::AbstractMiddleware
      def initialize(app, options = {})
        options[:instrument_span_name] = "process_request.grape"
        options[:report_errors] = lambda { |env| !env["grape.skip_appsignal_error"] }
        super
      end

      private

      def add_transaction_metadata_after(transaction, request)
        endpoint = request.env["api.endpoint"]
        unless endpoint&.options
          super
          return
        end

        options = endpoint.options
        request_method = options[:method].first.to_s.upcase
        klass = options[:for]
        namespace = endpoint.namespace
        namespace = "" if namespace == "/"

        path = options[:path].first.to_s
        path = "/#{path}" if path[0] != "/"
        path = "#{namespace}#{path}"

        transaction.set_action_if_nil("#{request_method}::#{klass}##{path}")

        super

        transaction.set_metadata("path", path)
      end
    end
  end
end
