# frozen_string_literal: true

require "rack"

module Appsignal
  # @api private
  module Rack
    class GenericInstrumentation
      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing Appsignal::Rack::GenericInstrumentation"
        @app = app
        @options = options
      end

      def call(env)
        if Appsignal.active?
          call_with_appsignal_monitoring(env)
        else
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
        body_read_will_complete = false
        begin
          Appsignal.instrument("process_action.generic") do
            status, headers, obody = @app.call(env)
            body_read_will_complete = true
            [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, transaction)]
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          default_action = env["appsignal.route"] || env["appsignal.action"] || "unknown"
          transaction.set_action_if_nil(default_action)
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", request.request_method)
          transaction.set_http_or_background_queue_start
          # Transaction gets completed when the body gets read out, except in cases when
          # the app failed before returning us the Rack response triplet.
          Appsignal::Transaction.complete_current! unless body_read_will_complete
        end
      end
    end
  end
end
