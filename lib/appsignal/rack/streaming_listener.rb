# frozen_string_literal: true

module Appsignal
  module Rack
    # Appsignal module that tracks exceptions in Streaming rack responses.
    #
    # @api private
    class StreamingListener
      def initialize(app, options = {})
        Appsignal.internal_logger.debug "Initializing Appsignal::Rack::StreamingListener"
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
        request = ::Rack::Request.new(env)
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request
        )

        # We need to complete the transaction if there is an exception exception inside the `call`
        # of the app. If there isn't one and the app returns us a Rack response triplet, we let
        # the BodyWrapper complete the transaction when #close gets called on it
        # (guaranteed by the webserver)
        complete_transaction_without_body = false

        # Instrument a `process_action`, to set params/action name
        begin
          Appsignal.instrument("process_action.rack") do
            status, headers, obody = @app.call(env)
            [status, headers, Appsignal::Rack::BodyWrapper.wrap(obody, transaction)]
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          complete_transaction_without_body = true
          raise error
        ensure
          transaction.set_action_if_nil(env["appsignal.action"])
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", request.request_method)
          transaction.set_http_or_background_queue_start

          # Transaction gets completed when the body gets read out, except in cases when
          # the app failed before returning us the Rack response triplet.
          Appsignal::Transaction.complete_current! if complete_transaction_without_body
        end
      end
    end
  end

  StreamWrapper = Rack::EnumerableBodyWrapper
end
