# frozen_string_literal: true

require "rack"

module Appsignal
  # @api private
  module Rack
    class RailsInstrumentation < GenericInstrumentation

      def call_with_appsignal_monitoring(env)
        request = ActionDispatch::Request.new(env)
        transaction = Appsignal::Transaction.create(
          request_id(env),
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          :params_method => :filtered_parameters
        )

        # Record the start of the response serving before we call into the upstream app
        transaction.set_http_or_background_queue_start

        begin
          status, headers, obody = @app.call(env)
          [status, headers, wrap_body(transaction, obody)]
        rescue Exception => error # rubocop:disable Lint/RescueException
          # These exceptions come from the controller or one of the Rack middlewares
          # upstream from this one, even before the body starts getting read
          transaction.set_error(error)
          raise error
        ensure
          controller = env["action_controller.instance"]
          if controller
            transaction.set_action_if_nil("#{controller.class}##{controller.action_name}")
          end
          transaction.set_metadata("path", request.path)
          begin
            transaction.set_metadata("method", request.request_method)
          rescue => error
            Appsignal.internal_logger.error("Unable to report HTTP request method: '#{error}'")
          end
        end
      end

      def request_id(env)
        env["action_dispatch.request_id"] || SecureRandom.uuid
      end
    end
  end
end
