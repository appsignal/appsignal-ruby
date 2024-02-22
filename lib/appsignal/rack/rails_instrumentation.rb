# frozen_string_literal: true

require "rack"

module Appsignal
  # @api private
  module Rack
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
          nil_transaction = Appsignal::Transaction::NilTransaction.new
          status, headers, obody = @app.call(env)
          [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, nil_transaction)]
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
        # We need to complete the transaction if there is an exception exception inside the `call`
        # of the app. If there isn't one and the app returns us a Rack response triplet, we let
        # the BodyWrapper complete the transaction when #close gets called on it
        # (guaranteed by the webserver)
        complete_transaction_without_body = false
        begin
          status, headers, obody = @app.call(env)
          [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, transaction)]
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          complete_transaction_without_body = true
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
            Appsignal.internal_logger.error("Unable to report HTTP request method: '#{error}'")
          end

          # Transaction gets completed when the body gets read out, except in cases when
          # the app failed before returning us the Rack response triplet.
          Appsignal::Transaction.complete_current! if complete_transaction_without_body
        end
      end

      def request_id(env)
        env["action_dispatch.request_id"] || SecureRandom.uuid
      end
    end
  end
end
