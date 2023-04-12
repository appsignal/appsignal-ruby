# frozen_string_literal: true

module Appsignal
  # @todo Move to sub-namespace
  # @api private
  module Grape
    class Middleware < ::Grape::Middleware::Base
      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          app.call(env)
        end
      end

      def call_with_appsignal_monitoring(env)
        request     = ::Rack::Request.new(env)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request
        )
        begin
          app.call(env)
        rescue Exception => error # rubocop:disable Lint/RescueException
          # Do not set error if "grape.skip_appsignal_error" is set to `true`.
          transaction.set_error(error) unless env["grape.skip_appsignal_error"]
          raise error
        ensure
          request_method = request.request_method.to_s.upcase
          path = request.path # Path without namespaces
          endpoint = env["api.endpoint"]

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
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
