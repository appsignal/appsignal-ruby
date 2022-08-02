# frozen_string_literal: true

require "rack"

module Appsignal
  # @api private
  module Rack
    class RailsInstrumentation
      def initialize(app, options = {})
        Appsignal.logger.debug "Initializing Appsignal::Rack::RailsInstrumentation"
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
        transaction = Appsignal::Transaction.create(
          request_id(env),
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          :params_method => :filtered_parameters
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
          transaction.set_http_or_background_queue_start
          transaction.set_metadata("path", request.path)
          begin
            transaction.set_metadata("method", request.request_method)
          rescue => error
            Appsignal.logger.error("Unable to report HTTP request method: '#{error}'")
          end
          Appsignal::Transaction.complete_current!
        end
      end

      def request_id(env)
        env["action_dispatch.request_id"] || SecureRandom.uuid
      end
    end
  end
end
