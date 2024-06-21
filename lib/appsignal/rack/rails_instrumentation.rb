# frozen_string_literal: true

require "rack"

module Appsignal
  module Rack
    # @api private
    class RailsInstrumentation
      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing Appsignal::Rack::RailsInstrumentation"
        @app = app
        @options = options
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          @app.call(env)
        end
      end

      def call_with_appsignal_monitoring(env)
        request = ActionDispatch::Request.new(env)
        transaction = env.fetch(
          Appsignal::Rack::APPSIGNAL_TRANSACTION,
          Appsignal::Transaction::NilTransaction.new
        )

        begin
          @app.call(env)
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          controller = env["action_controller.instance"]
          if controller
            transaction.set_action_if_nil("#{controller.class}##{controller.action_name}")
          end
          transaction.set_params_if_nil(fetch_params(request))
          request_id = fetch_request_id(env)
          transaction.set_tags(:request_id => request_id) if request_id
          transaction.set_metadata("path", request.path)
          request_method = fetch_request_method(request)
          transaction.set_metadata("method", request_method) if request_method
        end
      end

      def fetch_request_id(env)
        env["action_dispatch.request_id"]
      end

      def fetch_params(request)
        return unless request.respond_to?(:filtered_parameters)

        request.filtered_parameters
      rescue => error
        # Getting params from the request has been know to fail.
        Appsignal.internal_logger.debug "Exception while getting Rails params: #{error}"
        nil
      end

      def fetch_request_method(request)
        request.request_method
      rescue => error
        Appsignal.internal_logger.error("Unable to report HTTP request method: '#{error}'")
        nil
      end
    end
  end
end
