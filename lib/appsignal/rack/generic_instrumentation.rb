# frozen_string_literal: true

require "rack"

module Appsignal
  # @api private
  module Rack
    class GenericInstrumentation
      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing #{self.class.to_s}"
        @app = app
        @options = options
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
          # Apply the same body wrapping as when we are monitoring a transaction,
          # so that the behavior of the Rack stack does not change just because
          # Appsignal is active/inactive. Rack treats bodies in a special way which also
          # differs between Rack versions, so it is important to keep it consistent
          status, headers, obody = @app.call(env)
          [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, _transaction = nil)]
        end
      end

      def call_with_appsignal_monitoring(env)
        request = ::Rack::Request.new(env)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request
        )
        begin
          transaction.set_http_or_background_queue_start
          Appsignal.instrument("process_action.rack") do
            status, headers, body = @app.call(env)
            [status, headers, Appsignal::Rack::BodyWrapper.wrap(body, transaction)]
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          transaction.set_action_if_nil(env["appsignal.route"] || env["appsignal.action"] || "unknown")
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", request.request_method)
        end
      end
    end
  end
end
