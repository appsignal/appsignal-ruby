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

        # Instrument a `process_action`, to set params/action name
        status, headers, body =
          Appsignal.instrument("process_action.rack") do
            @app.call(env)
          rescue Exception => e # rubocop:disable Lint/RescueException
            transaction.set_error(e)
            raise e
          ensure
            transaction.set_action_if_nil(env["appsignal.action"])
            transaction.set_metadata("path", request.path)
            transaction.set_metadata("method", request.request_method)
            transaction.set_http_or_background_queue_start
          end

        # Wrap the result body with our StreamWrapper
        [status, headers, Appsignal::Rack::BodyWrapper.wrap(body, transaction)]
      end
    end
  end

  StreamWrapper = Rack::EnumerableBodyWrapper
end
